{%- from "ceph/map.jinja" import common with context %}

{% for name, keyring in common.get('keyring', {}).items() %}

ceph_create_keyring_{{ name }}:
  cmd.run:
  - name: "ceph -c /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.conf auth get-or-create client.{{ name }} {%- for cap_name, cap in  keyring.caps.items() %} {{ cap_name }} '{{ cap }}' {%- endfor %} > /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.{{ name }}.keyring"
  - unless: "test -f /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.{{ name }}.keyring"

{%- if name.startswith('bootstrap-') %}
ceph_keyring_{{ name}}:
  cmd.wait:
    - name: "ceph-authtool --create-keyring /var/lib/ceph/bootstrap-osd/{{ common.get('cluster_name', 'ceph') }}.keyring --import-keyring /etc/ceph/{{ common.get('cluster_name', 'ceph') }}.client.{{ name }}.keyring"
    - watch:
      - cmd: ceph_create_keyring_{{ name }}
{%- endif %}

{% endfor %}
