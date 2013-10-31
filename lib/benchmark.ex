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
          to_string :io_lib.format("~p seconds", [mcs / 1_000_000])

        mcs >= 1_000 ->
          to_string :io_lib.format("~p milliseconds", [mcs / 1_000])

        true ->
          to_string :io_lib.format("~p microseconds", [mcs])
      end
    end
  end

  defrecord Result, time: 0, result: nil do
    @type t :: Result[time: Time.t, result: any]
  end

  defmacro measure(do: block) do
    quote do
      { time, result } = :timer.tc(fn -> unquote(block) end)

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
      unless is_integer(unquote(n)) and unquote(n) > 1 do
        raise ArgumentError, message: "the number of times must be greater than 1"
      end

      func         = fn -> unquote(block) end
      { first, _ } = Benchmark.run(func)
      result       = Enum.reduce 1 .. unquote(n), { first, first, 0 }, fn
        _, { min, max, total } ->
          { current, _ } = Benchmark.run(func)

          { min(min, current), max(max, current), total + current }
      end

      { min, max, total } = result

      [ min: Benchmark.Time.at(min),
        max: Benchmark.Time.at(max),

        average: Benchmark.Time.at(total / unquote(n)),
        total:   Benchmark.Time.at(total),
        length:  unquote(n) ]
    end
  end

  @doc """
  Run a piece of code for a certain time and return statistics

  `d` is the minimum duration to run for in microseconds. The code
  block passed is executed as often as needed until the summed
  execution time exceeds `d`.

  Returns a list of key/value pairs with the following pieces of
  information: minimum/maximum/average/median time for one block
  invocation, number of invocations completed, total actual execution
  time and requested minimum execution time `d`.

  ## Example usage:

    iex> Benchmark.run_for 5000, do: :math.sqrt(20000)
    [min: 1 microseconds, max: 47 microseconds, median: 2 microseconds,
     average: 3.390921409214092 microseconds, total: 5.005 milliseconds,
     number: 1476, requested_duration: 5.0 milliseconds]

  """
  defmacro run_for(d, do: block) do
    quote do
      unless is_integer(unquote(d)) and unquote(d) > 0 do
        raise ArgumentError, message: "the duration must be greater than 0"
      end

      func  = fn -> unquote(block) end
      tests = Benchmark.run_for_executor(unquote(d), func)
        |> Enum.sort(fn { a, _ }, { b, _ } -> b > a end)

      total = Enum.reduce(tests, 0, fn({ t, _ }, sum) -> t + sum end)

      [ min: Benchmark.Time.at(elem(Enum.first(tests), 0)),
        max: Benchmark.Time.at(elem(List.last(tests), 0)),

        median: Benchmark.Time.at(elem(Enum.at(tests, round(length(tests) / 2)), 0)),
        average: Benchmark.Time.at(total / length(tests)),
        total: Benchmark.Time.at(total),
        number: length(tests),
        requested_duration: Benchmark.Time.at(unquote(d)) ]
    end
  end

  defp run_for_executor(d, func, total // 0, tests // []) do
    cond do
      total >= d ->
        tests

      true ->
        result = Benchmark.run(func)

        run_for_executor(d, func, total + elem(result, 0), [result | tests])
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
