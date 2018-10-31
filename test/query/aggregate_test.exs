defmodule Query.AggregateTest do
  use ExUnit.Case
  import FatEcto.FatQuery
  import Ecto.Query

  test "returns the query with aggregate count" do
    opts = %{
      "$aggregate" => %{"$count" => "beds"},
      "$where" => %{"beds" => 3}
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.beds == ^3 and ^true,
        select: merge(f, %{"$aggregate": %{"$count": %{^:beds => count(f.beds)}}})
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  test "returns the query with aggregate distinct count" do
    opts = %{
      "$aggregate" => %{"$count_distinct" => "nurses"},
      "$where" => %{"capacity" => 5},
      "$order" => %{"beds" => "$desc"}
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        order_by: [desc: f.beds],
        select:
          merge(f, %{"$aggregate": %{"$count_distinct": %{^:nurses => count(f.nurses, :distinct)}}})
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  test "returns the query with aggregate min" do
    opts = %{
      "$aggregate" => %{"$min" => "nurses"},
      "$where" => %{"capacity" => 5},
      "$order" => %{"beds" => "$desc"},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        order_by: [desc: f.beds],
        group_by: f.capacity,
        select: merge(f, %{"$aggregate": %{"$min": %{^:nurses => min(f.nurses)}}})
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  test "returns the query with aggregate max" do
    opts = %{
      "$aggregate" => %{"$max" => "nurses"},
      "$where" => %{"capacity" => 5},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        group_by: f.capacity,
        select: merge(f, %{"$aggregate": %{"$max": %{^:nurses => max(f.nurses)}}})
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  test "returns the query with aggregate sum" do
    opts = %{
      "$aggregate" => %{"$sum" => "nurses"},
      "$where" => %{"capacity" => 5},
      "$order" => %{"beds" => "$asc"},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        group_by: f.capacity,
        order_by: [asc: f.beds],
        select: merge(f, %{"$aggregate": %{"$sum": %{^:nurses => sum(f.nurses)}}})
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  test "returns the query with aggregate average" do
    opts = %{
      "$aggregate" => %{"$avg" => "level"},
      "$where" => %{"capacity" => 5},
      "$order" => %{"beds" => "$asc"},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        group_by: f.capacity,
        order_by: [asc: f.beds],
        select: merge(f, %{"$aggregate": %{"$avg": %{^:level => avg(f.level)}}})
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  test "returns the query with aggregate average/include" do
    opts = %{
      "$aggregate" => %{"$avg" => "level"},
      "$where" => %{"capacity" => 5},
      "$order" => %{"beds" => "$asc"},
      "$group" => "capacity",
      "$include" => %{
        "fat_hospital" => %{
          "$join" => "$full",
          "$order" => %{"id" => "$desc"},
          "$where" => %{"name" => "Saint"}
        }
      }
    }

    query =
      from(f in FatEcto.FatHospital,
        where: f.name == ^"Saint" and ^true,
        order_by: [desc: f.id],
        limit: ^10,
        offset: ^0
      )

    expected =
      from(f0 in FatEcto.FatRoom,
        full_join: f1 in assoc(f0, :fat_hospital),
        where: f0.capacity == ^5 and ^true,
        group_by: f0.capacity,
        order_by: [asc: f0.beds],
        select: merge(f0, %{"$aggregate": %{"$avg": %{^:level => avg(f0.level)}}}),
        preload: [fat_hospital: ^query]
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  @tag :failing
  test "returns the query with aggregate sum/join" do
    opts = %{
      "$aggregate" => %{"$sum" => "level"},
      "$where" => %{"capacity" => 5},
      "$order" => %{"beds" => "$asc"},
      "$group" => "capacity",
      "$right_join" => %{
        "fat_hospital" => %{
          "$on_field" => "hospital_id",
          "$on_join_table_field" => "id",
          "$select" => ["name", "location", "phone"],
          "$where" => %{"address" => "street 2"}
        }
      }
    }

    expected =
      from(f0 in FatEcto.FatRoom,
        right_join: f1 in "fat_hospital",
        on: f0.hospital_id == f1.id,
        where: f0.capacity == ^5 and ^true,
        where: f1.address == ^"street 2" and ^true,
        group_by: f0.capacity,
        order_by: [asc: f0.beds],
        select:
          merge(merge(f0, %{^:fat_hospital => map(f1, [:name, :location, :phone])}), %{
            "$aggregate": %{"$sum": %{^:level => sum(f0.level)}}
          })
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  test "returns the query with aggregate max/select" do
    opts = %{
      "$aggregate" => %{"$max" => "nurses"},
      "$where" => %{"capacity" => 5},
      "$group" => "capacity",
      "$select" => ["beds", "nurses", "capacity"]
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        group_by: f.capacity,
        select:
          merge(map(f, [:beds, :nurses, :capacity]), %{
            "$aggregate": %{"$max": %{^:nurses => max(f.nurses)}}
          })
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  @tag :failing
  test "returns the query with aggregate max/min" do
    opts = %{
      "$aggregate" => %{"$max" => "nurses", "$min" => "capacity"},
      "$where" => %{"capacity" => 5},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        group_by: f.capacity,
        select:
          merge(merge(f, %{"$aggregate": %{"$max": %{^:nurses => max(f.nurses)}}}), %{
            "$aggregate": %{"$min": %{^:capacity => min(f.capacity)}}
          })
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  @tag :failing
  test "returns the query with aggregate count/count_distinct" do
    opts = %{
      "$aggregate" => %{"$count" => "nurses", "$count_distinct" => "capacity"},
      "$where" => %{"capacity" => 5},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        group_by: f.capacity,
        select:
          merge(merge(f, %{"$aggregate": %{"$count": %{^:nurses => count(f.nurses)}}}), %{
            "$aggregate": %{"$count_distinct": %{^:capacity => count(f.capacity, :distinct)}}
          })
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  @tag :failing
  test "returns the query with aggregate sum/avg" do
    opts = %{
      "$aggregate" => %{"$sum" => "nurses", "$avg" => "capacity"},
      "$where" => %{"capacity" => 5},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        group_by: f.capacity,
        select:
          merge(merge(f, %{"$aggregate": %{"$avg": %{^:capacity => avg(f.capacity)}}}), %{
            "$aggregate": %{"$sum": %{^:nurses => sum(f.nurses)}}
          })
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  @tag :failing
  test "returns the query with aggregate sum/avg as a list" do
    opts = %{
      "$aggregate" => %{"$sum" => ["nurses", "beds"], "$avg" => ["capacity", "nurses"]},
      "$where" => %{"capacity" => 5},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        group_by: f.capacity,
        select:
          merge(
            merge(
              merge(merge(f, %{"$aggregate": %{"$avg": %{^:capacity => avg(f.capacity)}}}), %{
                "$aggregate": %{"$avg": %{^:nurses => avg(f.nurses)}}
              }),
              %{"$aggregate": %{"$sum": %{^:nurses => sum(f.nurses)}}}
            ),
            %{"$aggregate": %{"$sum": %{^:beds => sum(f.beds)}}}
          )
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  @tag :failing
  test "returns the query with aggregate count/count_distinct as a list" do
    opts = %{
      "$aggregate" => %{"$count" => ["nurses", "rating"], "$count_distinct" => ["capacity", "beds"]},
      "$where" => %{"capacity" => 5},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        group_by: f.capacity,
        select:
          merge(
            merge(
              merge(merge(f, %{"$aggregate": %{"$count": %{^:nurses => count(f.nurses)}}}), %{
                "$aggregate": %{"$count": %{^:rating => count(f.rating)}}
              }),
              %{"$aggregate": %{"$count_distinct": %{^:capacity => count(f.capacity, :distinct)}}}
            ),
            %{"$aggregate": %{"$count_distinct": %{^:beds => count(f.beds, :distinct)}}}
          )
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  @tag :failing
  test "returns the query with aggregate max/min as a list" do
    opts = %{
      "$aggregate" => %{"$max" => ["nurses", "beds"], "$min" => ["capacity", "level"]},
      "$where" => %{"capacity" => 5},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        group_by: f.capacity,
        select:
          merge(
            merge(
              merge(merge(f, %{"$aggregate": %{"$max": %{^:nurses => max(f.nurses)}}}), %{
                "$aggregate": %{"$max": %{^:beds => max(f.beds)}}
              }),
              %{"$aggregate": %{"$min": %{^:capacity => min(f.capacity)}}}
            ),
            %{"$aggregate": %{"$min": %{^:level => min(f.level)}}}
          )
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  @tag :failing
  test "returns the query with aggregate count as a list" do
    opts = %{
      "$aggregate" => %{"$count" => ["beds", "rating"]},
      "$where" => %{"beds" => 3}
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.beds == ^3 and ^true,
        select:
          merge(merge(f, %{"$aggregate": %{"$count": %{^:beds => count(f.beds)}}}), %{
            "$aggregate": %{"$count": %{^:rating => count(f.rating)}}
          })
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  @tag :failing
  test "returns the query with aggregate distinct count as a list" do
    opts = %{
      "$aggregate" => %{"$count_distinct" => ["nurses", "level"]},
      "$where" => %{"capacity" => 5},
      "$order" => %{"beds" => "$desc"}
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        order_by: [desc: f.beds],
        select:
          merge(
            merge(f, %{
              "$aggregate": %{"$count_distinct": %{^:nurses => count(f.nurses, :distinct)}}
            }),
            %{"$aggregate": %{"$count_distinct": %{^:level => count(f.level, :distinct)}}}
          )
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  @tag :failing
  test "returns the query with aggregate min as a list" do
    opts = %{
      "$aggregate" => %{"$min" => ["nurses", "capacity"]},
      "$where" => %{"capacity" => 5},
      "$order" => %{"beds" => "$desc"},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        order_by: [desc: f.beds],
        group_by: f.capacity,
        select:
          merge(merge(f, %{"$aggregate": %{"$min": %{^:nurses => min(f.nurses)}}}), %{
            "$aggregate": %{"$min": %{^:capacity => min(f.capacity)}}
          })
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  @tag :failing
  test "returns the query with aggregate max as a list" do
    opts = %{
      "$aggregate" => %{"$max" => ["nurses", "level"]},
      "$where" => %{"capacity" => 5},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        group_by: f.capacity,
        select:
          merge(merge(f, %{"$aggregate": %{"$max": %{^:nurses => max(f.nurses)}}}), %{
            "$aggregate": %{"$max": %{^:level => max(f.level)}}
          })
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  @tag :failing
  test "returns the query with aggregate sum as a list" do
    opts = %{
      "$aggregate" => %{"$sum" => ["nurses", "level"]},
      "$where" => %{"capacity" => 5},
      "$order" => %{"beds" => "$asc"},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        group_by: f.capacity,
        order_by: [asc: f.beds],
        select:
          merge(merge(f, %{"$aggregate": %{"$sum": %{^:nurses => sum(f.nurses)}}}), %{
            "$aggregate": %{"$sum": %{^:level => sum(f.level)}}
          })
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end

  @tag :failing
  test "returns the query with aggregate average as a list" do
    opts = %{
      "$aggregate" => %{"$avg" => ["level", "capacity"]},
      "$where" => %{"capacity" => 5},
      "$order" => %{"beds" => "$asc"},
      "$group" => "capacity"
    }

    expected =
      from(f in FatEcto.FatRoom,
        where: f.capacity == ^5 and ^true,
        group_by: f.capacity,
        order_by: [asc: f.beds],
        select:
          merge(merge(f, %{"$aggregate": %{"$avg": %{^:level => avg(f.level)}}}), %{
            "$aggregate": %{"$avg": %{^:capacity => avg(f.capacity)}}
          })
      )

    result = build(FatEcto.FatRoom, opts)
    assert inspect(result) == inspect(expected)
  end
end