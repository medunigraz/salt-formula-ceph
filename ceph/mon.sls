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


{%- if mon.get('msgr2', False) %}
ceph_mon_msgr2:
  cmd.run:
    - name: "ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf mon enable-msgr2"
{%- if not grains.get('noservices', False) %}
    - require:
      - service: ceph-mon@{{ grains.host }}
{%- endif %}
{%- endif %}

{% for name, keyring in common.get('keyring', {}).items() %}

ceph_create_keyring_{{ name }}:
  cmd.run:
  - name: "ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf auth get-or-create client.{{ name }} {%- for cap_name, cap in  keyring.caps.items() %} {{ cap_name }} '{{ cap }}' {%- endfor %} -o /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.{{ name }}.keyring"
  - unless: "test -f /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.{{ name }}.keyring"
  - require:
    - pkg: ceph_common_packages
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.admin.keyring
{%- if not grains.get('noservices', False) %}
    - service: ceph-mon@{{ grains.host }}
{%- endif %}

{% endfor %}

{%- if common.erasure_code_profiles is defined %}
{%- for name, options in common.erasure_code_profiles.items() %}
{%- if 'plugin' in options %}
erasure_code_profile_{{ name }}:
  cmd.run:
  - name: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd erasure-code-profile set {{ name }} {% for key, value in options.items() %}{{ key }}={{ value }}{% if not loop.last %} {% endif %}{% endfor %}
  - unless: ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf osd pool erasure-code-profile get {{ name }}
  - require:
    - pkg: ceph_common_packages
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf
    - file: /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.admin.keyring
{%- if not grains.get('noservices', False) %}
    - service: ceph-mon@{{ grains.host }}
{%- endif %}

{%- endif %}
{%- endfor %}
{%- endif %}
{%- endif %}
