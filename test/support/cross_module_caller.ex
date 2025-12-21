defmodule CrossModuleCaller do
  @moduledoc """
  Test module that calls functions in other modules to verify
  cross-module call extraction when processing individual files.
  """

  alias ExAst.Extractor.Stats

  def call_external_module do
    # Call to another project module
    stats = %Stats{total_calls: 5}
    Stats.record_success(stats, 1, 2, 3, 4, 5)
  end

  def call_stdlib do
    # Call to stdlib
    Enum.map([1, 2, 3], &(&1 * 2))
  end

  def call_local do
    # Local call
    helper()
  end

  defp helper do
    :ok
  end
end
