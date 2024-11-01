.PHONY: install
install:
	@mkdir --parents $${HOME}/.local/bin \
	&& mkdir --parents $${HOME}/.config/systemd/user \
	&& cp datadis_exporter $${HOME}/.local/bin/ \
	&& chmod +x $${HOME}/.local/bin/datadis_exporter \
	&& cp --no-clobber datadis_exporter.json $${HOME}/.config/datadis_exporter.json \
	&& chmod 400 $${HOME}/.config/datadis_exporter.json \
	&& cp datadis-exporter.timer $${HOME}/.config/systemd/user/ \
	&& cp datadis-exporter.service $${HOME}/.config/systemd/user/ \
	&& systemctl --user enable --now datadis-exporter.timer

.PHONY: uninstall
uninstall:
	@rm -f $${HOME}/.local/bin/datadis_exporter \
	&& rm -f $${HOME}/.config/datadis_exporter.json \
	&& systemctl --user disable --now datadis-exporter.timer \
	&& rm -f $${HOME}/.config/.config/systemd/user/datadis-exporter.timer \
	&& rm -f $${HOME}/.config/systemd/user/datadis-exporter.service

.PHONY: build
build:
	@go build -ldflags="-s -w" -o datadis_exporter main.go