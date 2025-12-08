defmodule CodeIntelligenceTracer.StatsTest do
  use ExUnit.Case, async: true

  alias CodeIntelligenceTracer.Stats

  describe "new/0" do
    test "creates stats with zero counts" do
      stats = Stats.new()

      assert stats.modules_processed == 0
      assert stats.modules_with_debug_info == 0
      assert stats.modules_without_debug_info == 0
      assert stats.total_calls == 0
      assert stats.total_functions == 0
      assert stats.total_specs == 0
      assert stats.total_types == 0
    end
  end

  describe "record_success/3" do
    test "increments modules_processed and modules_with_debug_info" do
      stats =
        Stats.new()
        |> Stats.record_success(10, 5)

      assert stats.modules_processed == 1
      assert stats.modules_with_debug_info == 1
      assert stats.modules_without_debug_info == 0
    end

    test "adds call and function counts" do
      stats =
        Stats.new()
        |> Stats.record_success(10, 5)

      assert stats.total_calls == 10
      assert stats.total_functions == 5
    end

    test "accumulates across multiple calls" do
      stats =
        Stats.new()
        |> Stats.record_success(10, 5)
        |> Stats.record_success(20, 8)
        |> Stats.record_success(5, 3)

      assert stats.modules_processed == 3
      assert stats.modules_with_debug_info == 3
      assert stats.total_calls == 35
      assert stats.total_functions == 16
    end
  end

  describe "record_failure/1" do
    test "increments modules_processed and modules_without_debug_info" do
      stats =
        Stats.new()
        |> Stats.record_failure()

      assert stats.modules_processed == 1
      assert stats.modules_with_debug_info == 0
      assert stats.modules_without_debug_info == 1
    end

    test "does not change call or function counts" do
      stats =
        Stats.new()
        |> Stats.record_failure()

      assert stats.total_calls == 0
      assert stats.total_functions == 0
    end

    test "accumulates with successes" do
      stats =
        Stats.new()
        |> Stats.record_success(10, 5)
        |> Stats.record_failure()
        |> Stats.record_success(20, 8)
        |> Stats.record_failure()

      assert stats.modules_processed == 4
      assert stats.modules_with_debug_info == 2
      assert stats.modules_without_debug_info == 2
      assert stats.total_calls == 30
      assert stats.total_functions == 13
    end
  end

  describe "to_map/1" do
    test "converts stats to map" do
      stats =
        Stats.new()
        |> Stats.record_success(10, 5)
        |> Stats.record_failure()

      map = Stats.to_map(stats)

      assert map == %{
               modules_processed: 2,
               modules_with_debug_info: 1,
               modules_without_debug_info: 1,
               total_calls: 10,
               total_functions: 5,
               total_specs: 0,
               total_types: 0
             }
    end

    test "handles zero counts" do
      map = Stats.to_map(Stats.new())

      assert map == %{
               modules_processed: 0,
               modules_with_debug_info: 0,
               modules_without_debug_info: 0,
               total_calls: 0,
               total_functions: 0,
               total_specs: 0,
               total_types: 0
             }
    end
  end

  describe "record_success/5 with specs and types" do
    test "tracks specs and types counts" do
      stats =
        Stats.new()
        |> Stats.record_success(10, 5, 3, 2)

      assert stats.total_specs == 3
      assert stats.total_types == 2
    end

    test "accumulates specs and types across multiple calls" do
      stats =
        Stats.new()
        |> Stats.record_success(10, 5, 3, 2)
        |> Stats.record_success(20, 8, 5, 1)

      assert stats.total_specs == 8
      assert stats.total_types == 3
    end
  end
end
