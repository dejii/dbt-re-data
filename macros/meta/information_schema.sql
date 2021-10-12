{% macro get_monitored_columns(for_schema) %}
    {% set splitted = for_schema.split('.') %}
    {% set splitted_length = splitted | length %}
    {% if splitted_length == 2 %}
        {{ adapter.dispatch('get_monitored_columns', 're_data')(splitted[1], splitted[0]) }}
    {% else %}
        {{ adapter.dispatch('get_monitored_columns', 're_data')(splitted[0], None) }}
    {% endif %}
{% endmacro %}

{% macro default__get_monitored_columns(table_schema, db_name) %}
    select
        {{full_table_name(table_name, table_schema, table_catalog) }} as table_name,
        column_name,
        data_type,
        is_nullable,
        {{- re_data.is_datetime('data_type') -}} as is_datetime,
        {{- re_data.time_filter('column_name', 'data_type') -}} as time_filter
    from
    {{ tables_in_schema(table_schema, db_name) }}
{% endmacro %}

{% macro redshift__get_monitored_columns(table_schema, db_name) %}

    {%- call statement('columns', fetch_result=True) -%}
    select
        {{full_table_name(table_name, table_schema, table_catalog) }} as table_name,
        column_name,
        data_type,
        is_nullable,
        {{- re_data.is_datetime('data_type')}} as is_datetime,
        {{- re_data.time_filter('column_name', 'data_type') -}} as time_filter
    from 
        {% if db_name %}{{db_name}}.{% endif %}information_schema.columns
    where
        table_schema = '{{ table_schema }}'
    {% endcall %}

    {%- set columns = load_result('columns')['data'] -%}
    {% set temp_table_name = 're_data_temporary_monitored_columns_for_' + table_schema %}

    {% set create_temp_table_query %}
        create temp table {{ temp_table_name }} (
            table_name {{ string_type()}},
            column_name {{ string_type()}},
            data_type {{ string_type() }},
            is_nullable {{ boolean_type() }},
            is_datetime {{ boolean_type() }},
            time_filter {{ string_type() }}
        );
        insert into {{ temp_table_name }}  values
        {% for col in columns %} (
            '{{col[0]}}'::text,
            '{{col[1]}}'::text,
            '{{col[2]}}'::text,
            '{{col[3]}}',
            {{col[4]}},
            {% if col[5] %} '{{col[5]}}'::text {% else %} null {% endif %}
            ) {%- if not loop.last %}, {%- endif %}
        {% endfor %}

    {% endset %}
    {% do run_query(create_temp_table_query) %}

    select table_name, column_name, data_type, is_nullable, is_datetime, time_filter
    from {{ temp_table_name }} 

{% endmacro %}

{% macro tables_in_schema(schema_name, db_name) %}
    {{ adapter.dispatch('tables_in_schema', 're_data')(schema_name, db_name) }}
{% endmacro %}

{% macro default__tables_in_schema(schema_name, db_name) %}
    {% if db_name %} {{ db_name}} . {% endif %} INFORMATION_SCHEMA.columns
    where
    table_schema = '{{ schema_name }}'
{% endmacro %}

{% macro bigquery__tables_in_schema(schema_name, db_name) %}
    {% if db_name %} `{{ db_name}}` . {% endif %} `{{schema_name}}` . `INFORMATION_SCHEMA`.`COLUMNS`
{% endmacro %}