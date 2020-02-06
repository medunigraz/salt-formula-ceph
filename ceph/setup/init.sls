{%- from "ceph/map.jinja" import common, setup with context %}
{%- if setup.enabled %}

include:
- ceph.common
{%- if setup.get('pool') %}
- ceph.setup.pool
{%- endif %}
{%- if setup.get('crush') %}
- ceph.setup.crush
{%- endif %}

{%- endif %}
