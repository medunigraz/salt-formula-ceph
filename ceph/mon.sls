{%- from "ceph/map.jinja" import common, mon with context %}

{%- if mon.get('enabled', False) %}

include:
- ceph.common

ceph_mon_packages:
  pkg.installed:
  - names: {{ mon.pkgs }}

/etc/ceph/{{ common.get('cluster_name', 'ceph') }}.mon.{{ grains.host }}.keyring:
  file.managed:
  - source: salt://ceph/files/mon_keyring
  - template: jinja
  - require:
    - file: /etc/ceph

ceph_generate_monmap:
  cmd.run:
  - name: "monmaptool --create {%- for member in common.members %} --add {{ member.name }} {{ member.host }} {%- endfor %} --fsid {{ common.fsid }} /var/lib/ceph/{{ common.get('cluster_name', 'ceph') }}.monmap"
  - unless: "test -f /var/lib/ceph/{{ common.get('cluster_name', 'ceph') }}.monmap"
  - require:
    - pkg: ceph_mon_packages

ceph_populate_monmap:
  cmd.run:
  - name: "sudo -u ceph ceph-mon -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf --mkfs -i {{ grains.host }} --monmap /var/lib/ceph/{{ common.get('cluster_name', 'ceph') }}.monmap --keyring /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.mon.{{ grains.host }}.keyring"
  - unless: "test -f /var/lib/ceph/mon/{{ common.get('cluster_name', 'ceph') }}-{{ grains.host }}/kv_backend"
  - require:
    - pkg: ceph_mon_packages
    - cmd: ceph_generate_monmap
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.mon.{{ grains.host }}.keyring

/var/lib/ceph/mon/{{ common.get('cluster_name', 'ceph') }}-{{ grains.host }}/done:
  file.managed:
  - user: ceph
  - group: ceph
  - content: { }
  - require:
    - pkg: ceph_mon_packages
    - cmd: ceph_populate_monmap

{%- if not grains.get('noservices', False) %}
ceph-mon@{{ grains.host }}:
  service.running:
  - enable: true
  - watch:
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
  - require:
    - pkg: ceph_mon_packages
    - file: /var/lib/ceph/mon/{{ common.get('cluster_name', 'ceph') }}-{{ grains.host }}/done
{%- endif %}

{%- endif %}
