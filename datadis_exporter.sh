#!/usr/bin/env bash

set -Eeo pipefail

dependencies=(awk curl date gzip jq)
for program in "${dependencies[@]}"; do
    command -v "$program" >/dev/null 2>&1 || {
        echo >&2 "Couldn't find dependency: $program. Aborting."
        exit 1
    }
done

if [[ "${RUNNING_IN_DOCKER}" ]]; then
    source "/app/datadis_exporter.conf"
elif [[ -f $CREDENTIALS_DIRECTORY/creds ]]; then
    # shellcheck source=/dev/null
    source "$CREDENTIALS_DIRECTORY/creds"
else
    source "./datadis_exporter.conf"
fi

[[ -z "${INFLUXDB_HOST}" ]] && echo >&2 "INFLUXDB_HOST is empty. Aborting" && exit 1
[[ -z "${INFLUXDB_API_TOKEN}" ]] && echo >&2 "INFLUXDB_API_TOKEN is empty. Aborting" && exit 1
[[ -z "${ORG}" ]] && echo >&2 "ORG is empty. Aborting" && exit 1
[[ -z "${BUCKET}" ]] && echo >&2 "BUCKET is empty. Aborting" && exit 1
[[ -z "${DATADIS_USERNAME}" ]] && echo >&2 "DATADIS_USERNAME is empty. Aborting" && exit 1
[[ -z "${DATADIS_PASSWORD}" ]] && echo >&2 "DATADIS_PASSWORD is empty. Aborting" && exit 1
[[ -z "${CUPS}" ]] && echo >&2 "CUPS is empty. Aborting" && exit 1
[[ -z "${DISTRIBUTOR_CODE}" ]] && echo >&2 "DISTRIBUTOR_CODE is empty. Aborting" && exit 1

AWK=$(command -v awk)
CURL=$(command -v curl)
DATE=$(command -v date)
GZIP=$(command -v gzip)
JQ=$(command -v jq)

TODAY=$($DATE +"%Y/%m/%d")
LAST_MONTH=$($DATE +"%Y/%m/%d" --date "1 month ago")
CURRENT_YEAR=$($DATE +"%Y")

INFLUXDB_URL="https://$INFLUXDB_HOST/api/v2/write?precision=s&org=$ORG&bucket=$BUCKET"
DATADIS_LOGIN_URL="https://datadis.es/nikola-auth/tokens/login"
DATADIS_SUPPLIES_API_URL="https://datadis.es/api-private/api/get-supplies"
DATADIS_CONTRACT_API_URL="https://datadis.es/api-private/supply-data/contractual-data"
DATADIS_CONSUMPTION_API_URL="https://datadis.es/api-private/supply-data/v2/time-curve-data/hours"
DATADIS_POWER_API_URL="https://datadis.es/api-private/supply-data/max-power"

datadis_token=$(
    $CURL --silent --fail --show-error \
        --request POST \
        --compressed \
        --header 'User-Agent: Mozilla/5.0' \
        --data "username=$DATADIS_USERNAME" \
        --data "password=$DATADIS_PASSWORD" \
        --data 'origin="WEB"' \
        "$DATADIS_LOGIN_URL"
)

datadis_point_type=$(
    $CURL --silent --fail --show-error \
        --compressed \
        --header "Accept: application/json" \
        --header 'Accept-Encoding: gzip, deflate, br' \
        --header 'User-Agent: Mozilla/5.0' \
        --header "Authorization: Bearer $datadis_token" \
        "$DATADIS_SUPPLIES_API_URL" |
        $JQ '.[].pointType'
)

datadis_contract=$(
    $CURL --silent --fail --show-error \
        --request POST \
        --compressed \
        --header "Accept: application/json" \
        --header 'Accept-Encoding: gzip, deflate, br' \
        --header "Authorization: Bearer $datadis_token" \
        --header 'Content-Type: application/json' \
        --header 'User-Agent: Mozilla/5.0' \
        --data-raw "{\"cups\":[\"$CUPS\"],\"distributor\":\"$DISTRIBUTOR_CODE\"}" \
        "$DATADIS_CONTRACT_API_URL" |
        $JQ '.response | .[]'
)

datadis_tarifa_code=$(echo $datadis_contract | $JQ --raw-output '.tarifaAccesoCode')
datadis_provincia_code=$(echo $datadis_contract | $JQ --raw-output '.provinciaCode')
datadis_autoconsumo=$(echo $datadis_contract | $JQ --raw-output '.tipoAutoConsumo')

datadis_json=$(
    $CURL --silent --fail --show-error \
        --request POST \
        --compressed \
        --header "Accept: application/json" \
        --header 'Accept-Encoding: gzip, deflate, br' \
        --header "Authorization: Bearer $datadis_token" \
        --header 'Content-Type: application/json' \
        --header 'User-Agent: Mozilla/5.0' \
        --data-raw "{ \"fechaInicial\":\"$LAST_MONTH\", \"fechaFinal\":\"$TODAY\", \"cups\":[\"$CUPS\"], \"distributor\":\"$DISTRIBUTOR_CODE\", \"fraccion\":0, \"hasAutoConsumo\":false, \"provinceCode\":\"$datadis_provincia_code\", \"tarifaCode\":\"$datadis_tarifa_code\", \"tipoPuntoMedida\":$datadis_point_type, \"tipoAutoConsumo\":$datadis_autoconsumo }" \
        "$DATADIS_CONSUMPTION_API_URL" |
        $JQ '.response.timeCurveList'
)

consumption_stats=$(
    echo "$datadis_json" |
        $JQ --raw-output "
        (.[] |
        [\"${CUPS}\",
        (if .period == \"PUNTA\" then \"1\" elif .period == \"LLANO\" then \"2\" elif .period == \"VALLE\" then \"3\" else empty end),
        .measureMagnitudeActive,
        ( (.date? + \" \" + ((if .hour == \"24:00\" then \"00:00\" else .hour end) | tostring)) | strptime(\"%Y/%m/%d %H:%M\") | todate | fromdate)
        ])
        | @tsv" |
        $AWK '{printf "datadis_consumption,cups=%s,period=%s consumption=%s %s\n", $1, $2, $3, $4}'
)

datadis_power_json=$(
    $CURL --silent --fail --show-error \
        --request POST \
        --compressed \
        --header "Accept: application/json" \
        --header 'Accept-Encoding: gzip, deflate, br' \
        --header "Authorization: Bearer $datadis_token" \
        --header 'Content-Type: application/json' \
        --header 'User-Agent: Mozilla/5.0' \
        --data-raw "{ \"cups\":[\"$CUPS\"], \"distributor\":\"$DISTRIBUTOR_CODE\", \"fechaFinal\":\"$CURRENT_YEAR/12/31\", \"fechaInicial\":\"$CURRENT_YEAR/01/01\" }" \
        "$DATADIS_POWER_API_URL" |
        $JQ '.response'
)

power_stats=$(
    echo "$datadis_power_json" |
        $JQ --raw-output "
         (.[] |
         [\"${CUPS}\",
         .periodo,
         .maximoPotenciaDemandada,
         ( (.fechaMaximo? + ((if .hora == \"24:00\" then \"00:00\" else .hora end) | tostring)) | strptime(\"%Y/%m/%d %H:%M\") | todate | fromdate)
         ])
         | @tsv" |
        $AWK '{printf "datadis_power,cups=%s,period=%s max_power=%s %s\n", $1, $2, $3, $4}'
)

stats=$(
    cat <<END_HEREDOC
$consumption_stats
$power_stats
END_HEREDOC
)

echo "${stats}" |
    $GZIP |
    $CURL --silent --fail --show-error \
        --request POST "${INFLUXDB_URL}" \
        --header 'Content-Encoding: gzip' \
        --header "Authorization: Token $INFLUXDB_API_TOKEN" \
        --header "Content-Type: text/plain; charset=utf-8" \
        --header "Accept: application/json" \
        --data-binary @-
