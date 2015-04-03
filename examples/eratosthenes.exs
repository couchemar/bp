defmodule Eratosthenes do

  def sequencer(i) when i < 100 do
    Bp.sync :bp, %Bp.Sync{request: [i]}
    t = Bp.sync :bp, %Bp.Sync{request: [:prime, :not_prime]}
    IO.puts "#{i} is #{inspect t}"
    sequencer(i+1)
  end
  def sequencer(_), do: IO.puts "---"

  def pFactors(i) do
    pFactors(2*i, i)
  end

  def pFactors(n,i) do
    Bp.sync :bp, %Bp.Sync{wait: [n]}
    Bp.sync :bp, %Bp.Sync{wait: [n + 1], block: [:prime]}
    pFactors(n+i, i)
  end

  def factory(i) do
    i = Bp.sync :bp, %Bp.Sync{wait: [i]}
    t = Bp.sync :bp, %Bp.Sync{wait: [:prime, :not_prime]}
    cond do
      t == :prime -> Bp.add :bp, fn() -> pFactors(i) end
      true -> :ok
    end
    factory(i + 1)
  end

  def run do
    bc = Bp.spawn
    Process.register bc, :bp
    Bp.add :bp, fn() -> sequencer(2) end
    Bp.add :bp, fn() -> factory(2) end
  end

end

require Logger
Logger.configure level: :info
Eratosthenes.run
receive do
  _ -> :ok
end
