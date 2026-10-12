# frozen_string_literal: true

# Rewrites form_descriptions.fallback_options into the shape of the
# rubykaigi.sponsor_app.internal.FallbackOptions message, {"options": [...]}.
class WrapFallbackOptions < ActiveRecord::Migration[8.1]
  def up
    # A legacy {value => name} Hash, or the {} default. Runs first, as the wrapped arrays below are objects too.
    execute <<~SQL.squish
      UPDATE form_descriptions
      SET fallback_options = jsonb_build_object('options', COALESCE(
        (
          SELECT jsonb_agg(jsonb_build_object('value', entry.key, 'name', entry.value #>> '{}') ORDER BY entry.position)
          FROM jsonb_each(fallback_options) WITH ORDINALITY AS entry(key, value, position)
        ),
        '[]'::jsonb
      ))
      WHERE jsonb_typeof(fallback_options) = 'object'
    SQL

    # Keys stay snake_case, the .proto field names FormDescription writes the column in.
    execute <<~SQL.squish
      UPDATE form_descriptions
      SET fallback_options = jsonb_build_object('options', fallback_options)
      WHERE jsonb_typeof(fallback_options) = 'array'
    SQL

    change_column_default :form_descriptions, :fallback_options, from: {}, to: {options: []}
  end

  # Back to the array the Hash-based reader took, with its snake_case keys and no empty members.
  def down
    change_column_default :form_descriptions, :fallback_options, from: {options: []}, to: {}

    execute <<~SQL.squish
      UPDATE form_descriptions
      SET fallback_options = COALESCE(
        (
          SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
            'value', option.value -> 'value',
            'name', option.value -> 'name',
            'conditions', (
              SELECT jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
                'plans', NULLIF(condition.value -> 'plans', '[]'::jsonb),
                'booth_request', COALESCE(condition.value -> 'booth_request', condition.value -> 'boothRequest')
              )) ORDER BY condition.position)
              FROM jsonb_array_elements(
                CASE jsonb_typeof(option.value -> 'conditions') WHEN 'array' THEN option.value -> 'conditions' END
              ) WITH ORDINALITY AS condition(value, position)
            ),
            'priority_human', NULLIF(
              COALESCE(option.value -> 'priority_human', option.value -> 'priorityHuman'),
              '[]'::jsonb
            )
          )) ORDER BY option.position)
          FROM jsonb_array_elements(fallback_options -> 'options') WITH ORDINALITY AS option(value, position)
        ),
        '[]'::jsonb
      )
    SQL
  end
end
