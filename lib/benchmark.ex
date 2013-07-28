defmodule Benchmark do
  defrecord Time, microseconds: 0 do
    @type t :: Time[microseconds: number]

    def at(time) do
      Time[microseconds: time]
    end
  end

  defimpl Inspect, for: Time do
    def inspect(Time[microseconds: mcs], _opts) do
      cond do
        mcs >= 1_000_000 ->
          to_binary :io_lib.format("~p seconds", [mcs / 1_000_000])

        mcs >= 1_000 ->
          to_binary :io_lib.format("~p milliseconds", [mcs / 1_000])

        true ->
          to_binary :io_lib.format("~p microseconds", [mcs])
      end
    end
  end

  defrecord Result, time: 0, result: nil do
    @type t :: Result[time: Time.t, result: any]
  end

  defmacro measure(do: block) do
    quote do
      { time, result } = :timer.tc(function(do: (() -> unquote(block))))

      Benchmark.Result[time: Benchmark.Time.at(time), result: result]
    end
  end

  defmacro measure(term) do
    quote do
      { time, result } = :timer.tc(unquote(term))

      Benchmark.Result[time: Benchmark.Time.at(time), result: result]
    end
  end

  def measure(fun, args) when is_function(fun, length args) do
    { time, result } = :timer.tc(fun, args)

    Benchmark.Result[time: Benchmark.Time.at(time), result: result]
  end

  def measure(module, fun, args) when is_function(fun, length args) do
    { time, result } = :timer.tc(module, fun, args)

    Benchmark.Result[time: Benchmark.Time.at(time), result: result]
  end

  defmacro time(do: block) do
    quote do
      Benchmark.measure(do: unquote(block)).time
    end
  end

  defmacro time(term) do
    quote do
      Benchmark.measure(unquote(term)).time
    end
  end

  def time(fun, args) when is_function(fun, length args) do
    Benchmark.measure(fun, args).time
  end

  def time(module, fun, args) when is_function(fun, length args) do
    Benchmark.measure(module, fun, args).time
  end

  defmacro times(n, do: block) do
    quote do
      func  = function(do: (() -> unquote(block)))
      tests = Enum.sort(Enum.map(1 .. unquote(n), fn(_) ->
        Benchmark.run(func)
      end), fn({ a, _ }, { b, _ }) ->
        b > a
      end)

      [ min: Benchmark.Time.at(elem(Enum.first(tests), 0)),
        max: Benchmark.Time.at(elem(List.last(tests), 0)),

        median: Benchmark.Time.at(elem(Enum.at(tests, div(length(tests), 2)), 0)),
        average: Benchmark.Time.at(List.foldl(tests, 0, fn({ t, _ }, sum) ->
          t + sum
        end) / length(tests)) ]
    end
  end

  @doc false
  def run(func) do
    self = Process.self
    id   = :random.uniform(10000000)

    Process.spawn_link fn ->
      self <- { Benchmark, id, :timer.tc(func) }
    end

    receive do
      { Benchmark, ^id, time } ->
        time
    end
  end
end
