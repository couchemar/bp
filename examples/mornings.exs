defmodule Test do

  @all_events [:morning, :evening]

  def display do
    event = Bp.sync :bp, %Bp.Sync{wait: @all_events}
    IO.puts "Good #{inspect event}"
    display
  end

  def morning do
    for _ <- 1..3 do
      Bp.sync :bp, %Bp.Sync{request: [:morning]}
    end
  end

  def evening do
    for _ <- 1..3 do
      Bp.sync :bp, %Bp.Sync{request: [:evening]}
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
    Bp.add :bp, &morning/0
    Bp.add :bp, &evening/0
    Bp.add :bp, &display/0
    Bp.add :bp, &interleave/0
    Bp.start :bp
  end

end

require Logger
Logger.configure level: :info
Test.test
receive do
  _ -> :ok
end
