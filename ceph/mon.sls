{%- from "ceph/map.jinja" import common, mon with context %}

include:
- ceph.common

mon_packages:
  pkg.installed:
  - names: {{ mon.pkgs }}

/etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf:
  file.managed:
  - source: salt://ceph/files/{{ common.version }}/ceph.conf.{{ grains.os_family }}
  - template: jinja
  - require:
    - pkg: mon_packages

generate_monmap:
  cmd.run:
  - name: "monmaptool --create {%- for member in common.members %} --add {{ member.name }} {{ member.host }} {%- endfor %} --fsid {{ common.fsid }} /var/lib/ceph/{{ common.get('cluster_name', 'ceph') }}.monmap"
  - unless: "test -f /var/lib/ceph/{{ common.get('cluster_name', 'ceph') }}.monmap"
  - require:
    - pkg: mon_packages

populate_monmap:
  cmd.run:
  - name: "sudo -u ceph ceph-mon -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf --mkfs -i {{ grains.host }} --monmap /var/lib/ceph/{{ common.get('cluster_name', 'ceph') }}.monmap"
  - unless: "test -f /var/lib/ceph/mon/{{ common.get('cluster_name', 'ceph') }}-{{ grains.host }}/kv_backend"
  - require:
    - pkg: mon_packages
    - cmd: generate_monmap

/var/lib/ceph/mon/{{ common.get('cluster_name', 'ceph') }}-{{ grains.host }}/keyring:
  file.managed:
  - source: salt://ceph/files/mon_keyring
  - template: jinja
  - require:
    - pkg: mon_packages

/var/lib/ceph/mon/{{ common.get('cluster_name', 'ceph') }}-{{ grains.host }}/done:
  file.managed:
  - user: ceph
  - group: ceph
  - content: { }
  - require:
    - pkg: mon_packages
    - file: /var/lib/ceph/mon/{{ common.get('cluster_name', 'ceph') }}-{{ grains.host }}/keyring
    - cmd: populate_monmap

{%- if not grains.get('noservices', False) %}
ceph-mon@{{ grains.host }}:
  service.running:
  - enable: true
  - watch:
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
  - require:
    - pkg: mon_packages
    - file: /var/lib/ceph/mon/{{ common.get('cluster_name', 'ceph') }}-{{ grains.host }}/done
{%- endif %}
