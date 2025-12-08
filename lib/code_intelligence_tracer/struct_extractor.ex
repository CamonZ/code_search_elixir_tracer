defmodule CodeIntelligenceTracer.StructExtractor do
  @moduledoc """
  Extracts struct definitions from BEAM file debug info.

  Parses the `:struct` key from Elixir debug info to extract field names
  and their default values.

  Note: @enforce_keys information is not preserved in BEAM files as it's
  only used at compile time. The `required` field is always `false` in
  the current implementation.
  """

  @type struct_info :: %{
          fields: [field_info()]
        }

  @type field_info :: %{
          field: String.t(),
          default: String.t(),
          required: boolean()
        }

  @doc """
  Extract struct definition from debug info.

  Returns a struct info map if the module defines a struct, `nil` otherwise.

  The struct info contains:
  - `:fields` - List of field maps with `:field`, `:default`, and `:required` keys

  ## Parameters

    - `debug_info` - Debug info map from `BeamReader.extract_debug_info/2`

  ## Examples

      iex> extract_struct(%{struct: [%{field: :name, default: nil}]})
      %{fields: [%{field: "name", default: "nil", required: false}]}

      iex> extract_struct(%{struct: nil})
      nil

  """
  @spec extract_struct(map()) :: struct_info() | nil
  def extract_struct(debug_info) do
    case debug_info[:struct] do
      nil -> nil
      [] -> nil
      fields when is_list(fields) -> format_struct(fields)
    end
  end

  defp format_struct(fields) do
    formatted_fields =
      fields
      |> Enum.map(&format_field/1)

    %{fields: formatted_fields}
  end

  defp format_field(%{field: field_name, default: default_value}) do
    %{
      field: Atom.to_string(field_name),
      default: inspect(default_value),
      required: false
    }
  end
end
