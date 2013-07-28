Code.require_file "../test_helper.exs", __FILE__

defmodule BenchmarkTest do
  use ExUnit.Case
	require Benchmark

  test "the truth" do
    assert(true)
  end

  test "benchmark 1 time doesn't throw ArgumentError" do
  	Benchmark.times 1, do: true
  end

end
