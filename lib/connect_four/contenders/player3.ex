defmodule ConnectFour.Contenders.Player3 do
  use GenServer
  import ConnectFour.BoardHelper

  def start(default) do
    GenServer.start(__MODULE__, default)
  end

  def handle_call(:name, _from, state) do
    {:reply, "Player 3 has entered", state}
  end

  def handle_call({:move, board}, _from, state) do
    move = move(board)
    {:reply, move, state}
  end

  def move(board) do
    [
      &find_winner(&1, 1),
      &find_winner(&1, 2),
      &min_max(&1, 1, 0, 0),
      &good_play_to_middle/1,
      &play_to_middle/1
    ] |> Enum.find_value(fn f -> f.(board) end)
  end

  def find_winner(board, player) do
    0..6
    |> Enum.find(fn column ->
      with {:ok, new_board} <- drop(board, player, column),
           {:winner, _} <- evaluate_board(new_board)
      do
        true
      else
        _ -> false
      end
    end)
  end

  defp good_play_to_middle(board) do
    [3, 2, 4, 1, 5, 0, 6]
    |> Enum.find(should_play?(board, 1))
  end

  defp play_to_middle(board) do
    [3, 2, 4, 1, 5, 0, 6]
    |> Enum.find(can_play?(board, 1))
  end

  defp should_play?(board, player) do
    fn column ->
      column_height = board
      |> select_column(column)
      |> Enum.reject(fn item -> item != 0 end)
      |> length

      match?({:ok, _}, drop(board, player, column)) && column_height >= 3
    end
  end

  defp select_column(board, num) do
    board
    |> rotate_board
    |> Enum.at(num)
  end

  defp rotate_board(board) do
    board
    |> Enum.with_index
    |> Enum.reduce(Enum.map(1..7, fn _ -> [] end), fn {row, _row_index}, acc ->
      Enum.zip(acc, row)
      |> Enum.map(fn {list, value} -> list ++ [value] end)
    end)
  end

  def min_max(board, player, score, depth) do
    {winning_boards, non_winning_boards} = winners_and_losers(board, player)

    next_player = 3 - player

    non_winning_boards = non_winning_boards
    |> Enum.map(fn {col,board} -> {col, min_max(board, next_player, score, depth + 1)} end) # Recurse into non-winning boards

    winning_score = calculate_winning_scores(winning_boards, player)
    non_winning_score = calculate_non_winning_scores(non_winning_boards)
    total_score = winning_score + non_winning_score

    if length(winning_boards) > 0 do
      col = winning_boards
      |> Enum.at(0)
      |> elem(0)
      {col, total_score}
    else
      winningest_board = non_winning_boards
      |> Enum.filter(fn {_col, {_subcol, score}} -> score > 0 end)
      |> Enum.max_by(fn {_col, {_subcol, score}} ->
        score
      end, fn ->
        {nil,{nil,nil}}
      end)

      if elem(winningest_board, 0) == nil && depth == 0 do
        nil
      else
        col = elem(winningest_board, 0)
        if depth == 0 do
          col
        else
          {col, total_score}
        end
      end
    end
  end

  def winners_and_losers(board, player) do
    0..6
    |> Enum.map(&Task.async(fn ->
      with true <- should_play?(board, player).(&1),
           {_col, {:ok, new_board}} <- drop(board, player, &1),
           {res, _} <- evaluate_board(new_board)
      do
        {&1, res || :loser}
      else
        _ ->
          {&1, false}
      end
    end))
    |> Enum.map(&Task.await/1)
    |> Enum.filter_map(fn {col, good?} -> good? end, fn {col, good?} -> col end)
    |> Enum.split(fn {col, res} -> res == :winner end)
  end

  def calculate_winning_scores(winning_boards, player) do
    winning_score = length(winning_boards)

    if player == 2 do
      0 - winning_score
    else
      winning_score
    end
  end

  def calculate_non_winning_scores(boards) do
    boards
    |> Enum.reduce(0, fn {_col,{_subcol, score}}, acc -> acc + score end)
  end

  defp can_play?(board, player) do
    fn column ->
      match?({:ok, _}, drop(board, player, column))
    end
  end
end
