defmodule Eratosthenes do

  def sequencer(i) when i < 100 do
    Bp.sync :bp, %Bp.Sync{wait: [i], request: [i]}
    t = Bp.sync :bp, %Bp.Sync{wait: [:prime, :not_prime],
                              request: [:prime, :not_prime]}
    IO.puts "#{i} is #{inspect t}"
    sequencer(i+1)
  end

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
      t == :prime -> Bp.add :bp, fn() -> pFactors(i) end, 1
      true -> :ok
    end
    factory(i + 1)
  end

  def run do
    bc = Bp.spawn
    Process.register bc, :bp
    Bp.add :bp, fn() -> sequencer(2) end, 3
    Bp.add :bp, fn() -> factory(2) end, 4
  end

end

require Logger
Logger.configure level: :info
Eratosthenes.run
receive do
  _ -> :ok
end
