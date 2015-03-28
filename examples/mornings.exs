defmodule Test do

  def display do
    event = Bp.sync :bp, %Bp.Sync{wait: [:morning, :evening]}
    IO.puts "Good #{inspect event}"
    display
  end

  def morning do
    for _ <- 1..3 do
      Bp.sync :bp, %Bp.Sync{wait: [:morning],
                            request: [:morning]}
    end
  end

  def evening do
    for _ <- 1..3 do
      Bp.sync :bp, %Bp.Sync{wait: [:evening],
                            request: [:evening]}
    end
  end

  def interleave do
    Bp.sync :bp, %Bp.Sync{wait: [:morning],
                          block: [:evening]}
    Bp.sync :bp, %Bp.Sync{wait: [:evening],
                            block: [:morning]}
    interleave
  end

  def test do
    bc = Bp.spawn
    Process.register bc, :bp
    Bp.add :bp, &morning/0, 1
    Bp.add :bp, &display/0, 2
    Bp.add :bp, &evening/0, 3
    Bp.add :bp, &interleave/0, 4
  end

end

Test.test
receive do
  _ -> :ok
end


