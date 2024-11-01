# datadis-exporter

CLI tool that uploads the energy consumption and maximum power usage data from the DATADIS API to influxdb on a daily basis

## Dependencies

- [go](https://go.dev/)
- [influxdb v2+](https://docs.influxdata.com/influxdb/v2.6/)
- Optional:
  - [make](https://www.gnu.org/software/make/) - for automatic installation support
  - [docker](https://docs.docker.com/)
  - [systemd](https://systemd.io/)

## Relevant documentation

- [DATADIS](https://datadis.es/)
- [InfluxDB API](https://docs.influxdata.com/influxdb/v2.6/write-data/developer-tools/api/)
- [Systemd Timers](https://www.freedesktop.org/software/systemd/man/systemd.timer.html)
- [compose-scheduler](https://github.com/reddec/compose-scheduler)

## Installation

### With Docker

#### docker-compose

1. Configure `datadis_exporter.json` (see the configuration section below).
1. Run it.

   ```bash
   docker compose up --detach
   ```

#### docker build & run

1. Build the docker image.

   ```bash
   docker build . --tag datadis-exporter
   ```

1. Configure `datadis_exporter.json` (see the configuration section below).
1. Run it.

    ```bash
    docker run --rm --init --tty --interactive --read-only --cap-drop ALL --security-opt no-new-privileges:true --cpus 2 -m 64m --pids-limit 16 --volume ./datadis_exporter.json:/app/datadis_exporter.json:ro ghcr.io/rare-magma/datadis-exporter:latest
    ```

### With the Makefile

For convenience, you can install this exporter with the following command or follow the manual process described in the next paragraph.

```bash
make build
make install
$EDITOR $HOME/.config/datadis_exporter.json
```

### Manually

1. Build `datadis_exporter` with:

    ```bash
    go build -ldflags="-s -w" -o datadis_exporter main.go
    ```

2. Copy `datadis_exporter` to `$HOME/.local/bin/` and make it executable.

3. Copy `datadis_exporter.json` to `$HOME/.config/`, configure it (see the configuration section below) and make it read only.

4. Copy the systemd unit and timer to `$HOME/.config/systemd/user/`:

    ```bash
    cp datadis-exporter.* $HOME/.config/systemd/user/
    ```

5. and run the following command to activate the timer:

    ```bash
    systemctl --user enable --now datadis-exporter.timer
    ```

It's possible to trigger the execution by running manually:

```bash
systemctl --user start datadis-exporter.service
```

### Config file

The config file has a few options:

```json
{
 "InfluxDBHost": "influxdb.example.com",
 "InfluxDBApiToken": "ZXhhbXBsZXRva2VuZXhhcXdzZGFzZGptcW9kcXdvZGptcXdvZHF3b2RqbXF3ZHFhc2RhCg==",
 "Org": "home",
 "Bucket": "datadis",
 "DatadisUsername": "username",
 "DatadisPassword": "password",
 "Cups": "ES0000000000000000XX0X",
 "DistributorCode": "1"
}
```

- `InfluxDBHost` should be the FQDN of the influxdb server.
- `Org` should be the name of the influxdb organization that contains the energy consumption data bucket defined below.
- `Bucket` should be the name of the influxdb bucket that will hold the energy consumption data.
- `InfluxDBApiToken` should be the influxdb API token value.
  - This token should have write access to the `BUCKET` defined above.
- `DatadisUsername` and `DATADIS_PASSWORD`should be the credentials used to access the DATADIS website
- `Cups` should be the Código Unificado de Punto de Suministro (CUPS)
- `DistributorCode` should be one of:
  - 1: Viesgo,
  - 2: E-distribución
  - 3: E-redes
  - 4: ASEME
  - 5: UFD
  - 6: EOSA
  - 7: CIDE
  - 8: IDE

## Troubleshooting

Check the systemd service logs and timer info with:

```bash
journalctl --user --unit datadis-exporter.service
systemctl --user list-timers
```

## Exported metrics

The consumption DATADIS API call period is limited to the last 30 days by default.
The power call is limited to the current year's first and last day.

- consumption: The energy consumption in kWh
- period: The period type (p1: punta, p2: llano, p3: valle)
- cups: The cups corresponding to the consumption point above
- max_power: The highest electrical power demanded in kWh

## Exported metrics example

```bash
datadis_consumption,cups=ES0000000000000000XX0X,period=1 consumption=0.123 1672610400
datadis_power,cups=ES0000000000000000XX0X,period=1 max_power=0.123 1686869100
```

## Example grafana dashboard

In `datadis-dashboard.json` there is an example of the kind of dashboard that can be built with `datadis-exporter` data:

<img src="dashboard-screenshot.png" title="Example grafana dashboard" width="100%">

Import it by doing the following:

1. Create a dashboard
2. Click the dashboard's settings button on the top right.
3. Go to JSON Model and then paste there the content of the `datadis-dashboard.json` file.

## Uninstallation

### With the Makefile

For convenience, you can uninstall this exporter with the following command or follow the process described in the next paragraph.

```bash
make uninstall
```

### Manually

Run the following command to deactivate the timer:

```bash
systemctl --user disable --now datadis-exporter.timer
```

Delete the following files:

```bash
~/.local/bin/datadis_exporter
~/.config/datadis_exporter.json
~/.config/systemd/user/datadis-exporter.timer
~/.config/systemd/user/datadis-exporter.service
```

## Credits

- [reddec/compose-scheduler](https://github.com/reddec/compose-scheduler)

This project takes inspiration from the following:

- [MrMarble/datadis](https://github.com/MrMarble/datadis)
