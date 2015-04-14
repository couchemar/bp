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
    end

  end

  defmodule EnforceTurns do

    @allXs (for s <- 1..9 do
      {:x, s}
    end)

    @allOs (for s <- 1..9 do
      {:o, s}
    end)

    def start, do: waitX

    defp waitX do
      Bp.sync :bp, %Bp.Sync{wait: @allXs, block: @allOs}
      waitO
    end

    defp waitO do
      Bp.sync :bp, %Bp.Sync{wait: @allOs, block: @allXs}
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

    @all_moves (for s <- 1..9 do
      {:x, s}
    end) ++ (for s <- 1..9 do
      {:o, s}
    end) ++ [{:win, :x}, {:win, :o}]

    def start do
      Bp.sync :bp, %Bp.Sync{request: @default_moves, wait: @all_moves}
      start
    end

  end


  defmodule PreventLineWithTwo do

    def start(squares), do: loop(squares)

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

    def wait_frist(s = [s1, s2], e = [j, e1, e2]) do
      wait = (for sq <- s ++ e do
                {:x, sq}
      end) ++ (for sq <- e do
                 {:o, sq}
      end)
      case Bp.sync :bp, %Bp.Sync{wait: wait} do
        {:x, s} when s == s1; s == s2 -> wait_second s, e
        {_, s} when s == j; s == e1; s == e2 -> :ok
      end
    end

    def wait_second(s = [s1, s2], e = [j, e1, e2]) do
      wait = (for sq <- s ++ e do
                {:x, sq}
      end) ++ (for sq <- e do
                 {:o, sq}
      end)
      case Bp.sync :bp, %Bp.Sync{wait: wait} do
        {:x, s} when s == s1; s == s2 -> intercept(j)
        {_, s} when s == j; s == e1; s == e2 -> :ok
      end
    end

    defp intercept(square) do
      Bp.sync :bp, %Bp.Sync{request: [{:o, square}]}
    end

  end


  defmodule InterceptDoubleFork do
    
  end

end


