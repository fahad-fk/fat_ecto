defmodule FatUtils.Changeset do
  def xor(changeset, record, xor_keys, _options \\ []) do
    changeset =
      if FatUtils.Map.has_all_keys?(changeset.changes, xor_keys) do
        error_msg = Enum.join(xor_keys, " XOR ")

        Enum.reduce(xor_keys, changeset, fn xor_key, acc ->
          Ecto.Changeset.add_error(acc, xor_key, error_msg)
        end)
      else
        changeset
      end

    if !FatUtils.Map.has_any_of_keys?(changeset.changes, xor_keys) &&
         FatUtils.Map.has_all_val_equal_to?(record, xor_keys, nil) do
      require_msg = Enum.join(xor_keys, " XOR ") <> " fields can not be empty at the same time"

      Enum.reduce(xor_keys, changeset, fn xor_key, acc ->
        Ecto.Changeset.validate_required(
          acc,
          [xor_key],
          message: require_msg
        )
      end)
    else
      changeset
    end
  end

  def require_if_change_present(changeset, if_change_key: if_change_key, require_key: require_key) do
    if Map.has_key?(changeset.changes, if_change_key) do
      Ecto.Changeset.validate_required(
        changeset,
        require_key
      )
    else
      changeset
    end
  end

  def validate_before(changeset, start_date_key, end_date_key, options \\ []) do
    start_date = Ecto.Changeset.get_field(changeset, start_date_key)
    end_date = Ecto.Changeset.get_field(changeset, end_date_key)

    cond do
      options[:compare_type] == :time ->
        if start_date && end_date && Time.diff(end_date, start_date) <= 0 do
          Ecto.Changeset.add_error(changeset, start_date_key, "must be before #{end_date_key}")
        else
          changeset
        end

      true ->
        if start_date && end_date && DateTime.diff(end_date, start_date) <= 0 do
          Ecto.Changeset.add_error(changeset, start_date_key, "must be before #{end_date_key}")
        else
          changeset
        end
    end
  end
end