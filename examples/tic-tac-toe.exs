defmodule Events do

  @allXs (for s <- 1..9 do
            {:x, s}
  end)

  @allOs (for s <- 1..9 do
            {:o, s}
  end)

  @wins [{:win, :x}, {:win, :o}]

  @all @allXs ++ @allOs ++ @wins ++ [:tie]

  def all do
    @all
  end

  def allXs do
    @allXs
  end

  def allOs do
    @allOs
  end

end

defmodule TTT do

  @moduledoc """
  Board squares
  |1|2|3|
  |4|5|6|
  |7|8|9|
  """
  defmodule DetectWin do

    def start(player, squares), do: loop(player, squares)

    defp loop(player, [square|rest]) do
      Bp.sync :bp, %Bp.Sync{wait: [{player, square}]}
      loop(player, rest)
    end
    defp loop(player, []), do: declare_win(player)

    defp declare_win(player) do
      Bp.sync :bp, %Bp.Sync{request: [{:win, player}]}
      Bp.sync :bp, %Bp.Sync{block: Events.all  -- [{:win, player}]}
    end

  end

  defmodule DetectTie do
    def start, do: loop(1..9 |> Enum.to_list)

    defp loop([]) do
      Bp.sync :bp, %Bp.Sync{request: [:tie]}
      Bp.sync :bp, %Bp.Sync{block: Events.all}
    end
    defp loop(squares) do
      {_, square} = Bp.sync :bp, %Bp.Sync{wait: Events.all}
      loop(squares -- [square])
    end

  end

  defmodule EnforceTurns do
    def start, do: waitX

    defp waitX do
      Bp.sync :bp, %Bp.Sync{wait: Events.allXs, block: Events.allOs}
      waitO
    end

    defp waitO do
      Bp.sync :bp, %Bp.Sync{wait: Events.allOs, block: Events.allXs}
      waitX
    end

  end


  defmodule DisallowSquareReuse do

    def start(square) do
      Bp.sync :bp, %Bp.Sync{wait: [{:x, square}, {:o, square}]}
      Bp.sync :bp, %Bp.Sync{block: [{:x, square}, {:o, square}]}
    end

  end


  defmodule DefaultMoves do

    @default_moves [
      {:o, 5},
      {:o, 1},
      {:o, 3},
      {:o, 7},
      {:o, 9},
      {:o, 2},
      {:o, 4},
      {:o, 6},
      {:o, 8}
    ]

    def start do
      Bp.sync :bp, %Bp.Sync{request: @default_moves, wait: Events.all}
      start
    end

  end


  defmodule PreventLineWithTwo do
    def start(squares) do
      loop(squares)
    end

    defp loop([last_square|[]]), do: prevent(last_square)
    defp loop([square|rest]) do
      Bp.sync :bp, %Bp.Sync{wait: [{:x, square}]}
      loop rest
    end

    defp prevent(last_square) do
      Bp.sync :bp, %Bp.Sync{request: [{:o, last_square}]}
    end

  end

  defmodule CompleteLineWithTwo do
    def start(squares) do
      loop squares
    end

    defp loop([last_square|[]]), do: complete(last_square)
    defp loop([square|rest]) do
      Bp.sync :bp, %Bp.Sync{wait: [{:o, square}]}
      loop rest
    end

    defp complete(last_square) do
      Bp.sync :bp, %Bp.Sync{request: [{:o, last_square}]}
    end

  end


  defmodule InterceptSingleFork do

    def start(s, e) do
      wait_first s, e
    end

    def wait_first(s = [s1, s2], e = [j, e1, e2]) do
      wait = (for sq <- s ++ e do
                {:x, sq}
      end) ++ (for sq <- e do
                 {:o, sq}
      end)
      case Bp.sync :bp, %Bp.Sync{wait: wait} do
        {:x, sq} when sq == s1 or sq == s2 -> wait_second s, e
        {_, sq} when sq == j or sq == e1 or sq == e2 -> :ok
      end
    end

    def wait_second(s = [s1, s2], e = [j, e1, e2]) do
      wait = (for sq <- s ++ e do
                {:x, sq}
      end) ++ (for sq <- e do
                 {:o, sq}
      end)
      case Bp.sync :bp, %Bp.Sync{wait: wait} do
        {:x, sq} when sq == s1 or sq == s2 -> intercept(j)
        {_, sq} when sq == j or sq == e1 or sq == e2 -> :ok
      end
    end

    defp intercept(square) do
      Bp.sync :bp, %Bp.Sync{request: [{:o, square}]}
    end

  end


  defmodule InterceptDoubleFork do

    def start(opposite_corners) do
      Bp.sync :bp, %Bp.Sync{wait: (for sq <- opposite_corners do
                                     {:x, sq}
                               end)}
      wait_center opposite_corners
    end

    def wait_center(opposite_corners) do
      Bp.sync :bp, %Bp.Sync{wait: [{:o, 5}]}
      wait_rest opposite_corners
    end

    def wait_rest(opposite_corners) do
      Bp.sync :bp, %Bp.Sync{wait: (for sq <- opposite_corners do
                                     {:x, sq}
                               end)}
      attack
    end

    defp attack do
      Bp.sync :bp, %Bp.Sync{request: [{:o, 2}]}
    end

  end

end

defmodule Utils do
  def permutations([]), do: [[]]
  def permutations(l) do
    for h <- l, t <- permutations(l -- [h]) do
      [h | t]
    end
  end
end

require Logger
Logger.configure level: :info

require Bp

bc = Bp.spawn
Process.register bc, :bp

lines = [
  [1, 2, 3],
  [4, 5, 6],
  [7, 8, 9],

  [1, 4, 7],
  [2, 5, 8],
  [3, 6, 9],

  [1, 5, 9],
  [3, 5, 7]
]

for player <- [:x, :o], line <- lines, perm <- Utils.permutations(line) do
  Bp.add :bp, fn() -> TTT.DetectWin.start(player, perm) end, 0
end

Bp.add :bp, &TTT.DetectTie.start/0, 0

Bp.add :bp, &TTT.EnforceTurns.start/0, 1

for square <- 1..9 do
  Bp.add :bp, fn() -> TTT.DisallowSquareReuse.start(square) end, 2
end

Bp.add :bp, &TTT.DefaultMoves.start/0, 12

for line <- lines, perm <- Utils.permutations(line) do
  Bp.add :bp, fn() -> TTT.PreventLineWithTwo.start(perm) end, 9
end

for line <- lines, perm <- Utils.permutations(line) do
  Bp.add :bp, fn() -> TTT.CompleteLineWithTwo.start(perm) end, 8
end

for line <- lines, rest <- lines -- [line] do
  sl = line |> Enum.into(HashSet.new)
  sr = rest |> Enum.into(HashSet.new)

  dif = Set.difference(sl, sr) |> Enum.to_list
  case length(dif) do
    3 -> " "
    2 -> Bp.add :bp, fn() -> TTT.InterceptSingleFork.start(dif, rest) end, 10
  end
end

Bp.add :bp, fn() -> TTT.InterceptDoubleFork.start([1, 9]) end, 11
Bp.add :bp, fn() -> TTT.InterceptDoubleFork.start([3, 7]) end, 11

defmodule PrintEvents do
  def print(events) do
    squares = for {k,v} <- events do
      {v, k}
    end |> Enum.sort

    for line <- expand(squares, 1, []) |> Enum.chunk(3) do
      line |> Enum.join(" | ") |> IO.puts
    end
  end

  defp expand(_, _, board) when length(board) == 9, do: Enum.reverse(board)
  defp expand([], index, board), do: expand([], index + 1, [" "|board])
  defp expand(squares, index, board) do
   [{ix, player}|rest] = squares
   cond do
     ix < index -> expand(rest, index, [player|board])
     ix == index -> expand(rest, index + 1, [player|board])
     true -> expand(squares, index + 1, [" "|board])
   end
  end
end

defmodule Display do

  def start, do: loop(1, [])

  defp loop(round, events) do
    event = Bp.sync :bp, %Bp.Sync{wait: Events.all}
    case event do
      {:win, player} ->
        IO.puts "Player \"#{player}\" wins"
      :tie ->
        IO.puts "Tie"
      _ ->
        IO.puts "Round #{round}"
        IO.puts "========="
        events = [event|events]
        events |> PrintEvents.print
        loop(round + 1, events)
    end
  end
end

Bp.add :bp, &Display.start/0

dummy = fn(self) ->
  :random.seed(:os.timestamp)
  Bp.sync :bp, %Bp.Sync{request: Events.allXs |> Enum.shuffle, wait: Events.all}
  self.(self)
end

Bp.add :bp, fn() -> dummy.(dummy) end, 5

Bp.start :bp

receive do
  _ -> :ok
end
