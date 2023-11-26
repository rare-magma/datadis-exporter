.PHONY: install
install:
	@mkdir --parents $${HOME}/.local/bin \
	&& mkdir --parents $${HOME}/.config/systemd/user \
	&& cp datadis_exporter.sh $${HOME}/.local/bin/ \
	&& chmod +x $${HOME}/.local/bin/datadis_exporter.sh \
	&& cp --no-clobber datadis_exporter.conf $${HOME}/.config/datadis_exporter.conf \
	&& chmod 400 $${HOME}/.config/datadis_exporter.conf \
	&& cp datadis-exporter.timer $${HOME}/.config/systemd/user/ \
	&& cp datadis-exporter.service $${HOME}/.config/systemd/user/ \
	&& systemctl --user enable --now datadis-exporter.timer

.PHONY: uninstall
uninstall:
	@rm -f $${HOME}/.local/bin/datadis_exporter.sh \
	&& rm -f $${HOME}/.config/datadis_exporter.conf \
	&& systemctl --user disable --now datadis-exporter.timer \
	&& rm -f $${HOME}/.config/.config/systemd/user/datadis-exporter.timer \
	&& rm -f $${HOME}/.config/systemd/user/datadis-exporter.service
