defmodule ExAst.Extractor.SpecExtractor.TypeDefinitionExtractor do
  alias ExAst.Extractor.TypeAst

  @moduledoc """
  Extracts @type and @opaque definitions from BEAM file abstract_code chunks.

  Parses the definitions list from abstract_code to extract type metadata
  including name, kind (type/opaque), parameters, line numbers, and
  formatted definitions.
  """

  @type type_record :: %{
          name: atom(),
          kind: :type | :opaque,
          params: [atom()],
          line: non_neg_integer(),
          definition: String.t()
        }

  @doc """
  Extract @type and @opaque definitions from BEAM chunks.

  Parses the `:abstract_code` chunk to find type and opaque type definitions.

  Returns a list of type records with:
  - `:name` - type name as atom
  - `:kind` - `:type` or `:opaque`
  - `:params` - list of type parameter names (atoms)
  - `:line` - source line number
  - `:definition` - formatted definition string like `@type t :: integer()`

  Returns an empty list if no abstract_code chunk is available.

  ## Examples

      iex> {:ok, {_mod, chunks}} = BeamReader.read_chunks("path/to/Module.beam")
      iex> extract_types(chunks)
      [%{name: :t, kind: :type, params: [], line: 5, definition: "@type t :: integer()"}]

  """
  @spec extract_types(map()) :: [type_record()]
  def extract_types(chunks) do
    case chunks[:abstract_code] do
      {:raw_abstract_v1, forms} ->
        extract_types_from_forms(forms)

      nil ->
        []

      _other ->
        []
    end
  end

  defp extract_types_from_forms(forms) do
    forms
    |> Enum.filter(&type_or_opaque?/1)
    |> Enum.map(&parse_type_attribute/1)
    |> Enum.reject(&is_nil/1)
  end

  defp type_or_opaque?({:attribute, _, :type, _}), do: true
  defp type_or_opaque?({:attribute, _, :opaque, _}), do: true
  defp type_or_opaque?(_), do: false

  defp parse_type_attribute({:attribute, line, kind, {name, type_ast, params}})
       when kind in [:type, :opaque] do
    param_names = extract_param_names(params)
    definition = format_type_definition(name, kind, param_names, type_ast)

    %{
      name: name,
      kind: kind,
      params: param_names,
      line: line,
      definition: definition
    }
  end

  defp parse_type_attribute(_), do: nil

  defp extract_param_names(params) when is_list(params) do
    Enum.map(params, fn
      {:var, _, name} -> name
      _ -> :_
    end)
  end

  defp extract_param_names(_), do: []

  defp format_type_definition(name, kind, params, type_ast) do
    prefix = if kind == :opaque, do: "@opaque", else: "@type"
    type_string = TypeAst.format(TypeAst.parse(type_ast))

    if params == [] do
      "#{prefix} #{name}() :: #{type_string}"
    else
      params_str = Enum.join(params, ", ")
      "#{prefix} #{name}(#{params_str}) :: #{type_string}"
    end
  end
end
