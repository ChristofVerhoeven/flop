# Flop

![CI](https://github.com/woylie/flop/workflows/CI/badge.svg) [![Hex](https://img.shields.io/hexpm/v/flop)](https://hex.pm/packages/flop) [![Coverage Status](https://coveralls.io/repos/github/woylie/flop/badge.svg)](https://coveralls.io/github/woylie/flop)

Flop is an Elixir library that applies filtering, ordering and pagination
parameters to your Ecto queries.

## Features

- offset-based pagination with `offset`/`limit` or `page`/`page_size`
- cursor-based pagination (aka key set pagination), compatible with Relay pagination arguments
- ordering by multiple fields in multiple directions
- filtering by multiple conditions with various operators on multiple fields
- parameter validation
- configurable filterable and sortable fields
- join fields
- compound fields
- query and meta data helpers
- Relay connection formatter (edges, nodes and page info)
- UI helpers and URL builders through [Flop Phoenix](https://hex.pm/packages/flop_phoenix).

## Status

This library has been used in production for a while now. Nevertheless, there
may still be API changes on the way to a more complete feature set.

## Installation

Add `flop` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:flop, "~> 0.16.1"}
  ]
end
```

If you want to configure a default repo, add this to your config file:

```elixir
config :flop, repo: MyApp.Repo
```

Alternatively, you can add a configuration module. For more information, refer
to the Flop module documentation.

## Usage

### Define sortable and filterable fields

To configure the sortable and filterable fields, derive `Flop.Schema` in your
Ecto schema. While this step is optional, it is highly recommend, since the
parameters you will pass to the Flop functions will come from the user side and
should be validated. Deriving `Flop.Schema` will ensure that Flop only
applies filtering and sorting parameters on the configured fields.

```elixir
defmodule MyApp.Pet do
  use Ecto.Schema

  @derive {
    Flop.Schema,
    filterable: [:name, :species],
    sortable: [:name, :age, :species]
  }

  schema "pets" do
    field :name, :string
    field :age, :integer
    field :species, :string
    field :social_security_number, :string
  end
end
```

You can also define join fields, compound fields, max and default limit, and
more. See the [Flop.Schema documentation](https://hexdocs.pm/flop/Flop.Schema.html)
for all the options.

### Query data

You can use `Flop.validate_and_run/3` or `Flop.validate_and_run!/3` to validate
the Flop parameters, retrieve the data from the database and get the meta data
for pagination in one go.

```elixir
defmodule MyApp.Pets do
  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Flop
  alias MyApp.{Pet, Repo}

  @spec list_pets(Flop.t()) ::
          {:ok, {[Pet.t()], Flop.Meta.t}} | {:error, Changeset.t()}
  def list_pets(flop \\ %Flop{}) do
    Flop.validate_and_run(Pet, flop, for: Pet)
  end
end
```

The `for` option sets the Ecto schema for which you derived `Flop.Schema`. If
you didn't derive Flop.Schema as described above and don't care to do so,
you can omit this option (not recommended, unless you only deal with internally
generated, safe parameters).

On success, `Flop.validate_and_run/3` returns an `:ok` tuple, with the second
element being a tuple with the data and the meta data.

```elixir
{:ok, {[%Pet{}], %Flop.Meta{}}}
```

Consult the [docs](https://hexdocs.pm/flop/Flop.Meta.html) for more info on the
`Meta` struct.

If you prefer to validate the parameters in your controllers, you can use
`Flop.validate/2` or `Flop.validate!/2` and `Flop.run/3` instead.

```elixir
defmodule MyAppWeb.PetController do
  use MyAppWeb, :controller

  alias Flop
  alias MyApp.Pets
  alias MyApp.Pets.Pet

  action_fallback MyAppWeb.FallbackController

  def index(conn, params) do
    with {:ok, flop} <- Flop.validate(params, for: Pet) do
      pets = Pets.list_pets(flop)
      render(conn, "index.html", pets: pets)
    end
  end
end

defmodule MyApp.Pets do
  import Ecto.Query, warn: false

  alias Flop
  alias MyApp.Pets.Pet
  alias MyApp.Repo

  @spec list_pets(Flop.t()) :: {[Pet.t()], Flop.Meta.t}
  def list_pets(flop \\ %Flop{}) do
    Flop.run(Pet, flop, for: Pet)
  end
end
```

If you only need the data, or if you only need the meta data, you can also
call `Flop.all/3`, `Flop.meta/3` or `Flop.count/3` directly. Note that these
functions do not apply parameter validation. If the parameters are generated
through a user action, always use `Flop.validate/2` or `Flop.validate!/2`
first.

If you didn't configure a default repo as described above or if you want to
override the default repo, you can pass it as an option to any function that
uses the repo:

```elixir
Flop.validate_and_run(Pet, flop, repo: MyApp.Repo)
Flop.all(Pet, flop, repo: MyApp.Repo)
Flop.meta(Pet, flop, repo: MyApp.Repo)
# etc.
```

See the [docs](https://hexdocs.pm/flop/readme.html) for more detailed
information.

## Internal parameters

Flop is built to handle parameters generated by a user. While you could
manipulate those parameters and add additional filters when you receive them, it
is recommended to cleanly separate the parameters you get from the outside and
the parameters that your application needs to add internally.

For example, if you need to scope a query depending on the current user, it is
preferred to add a separate function that adds the necessary `WHERE` clauses:

```elixir
def list_pets(%{} = args, %User{} = current_user) do
  Pet
  |> scope(current_user)
  |> Flop.validate_and_run(flop, for: Pet)
end

defp scope(q, %User{role: :admin}), do: q
defp scope(q, %User{id: user_id}), do: where(q, user_id: ^user_id)
```

To add additional filters that can only be used internally without exposing them
to the user, you can pass them as a separate argument. You can use the same
argument to override certain options depending on where the function is used.

```elixir
def list_pets(%{} = args, opts \\ [], %User{} = current_user) do
  flop_opts =
    opts
    |> Keyword.take([
      :default_limit,
      :default_pagination_type,
      :pagination_types
    ])
    |> Keyword.put(:for, Pet)

  Pet
  |> scope(current_user)
  |> apply_filters(opts)
  |> Flop.validate_and_run(flop, flop_opts)
end

defp scope(q, %User{role: :admin}), do: q
defp scope(q, %User{id: user_id}), do: where(q, user_id: ^user_id)

defp apply_filters(q, opts) do
  Enum.reduce(opts, q, fn
    {:last_health_check, dt}, q -> where(q, [p], p.last_health_check < ^dt)
    {:reminder_service, bool}, q -> where(q, [p], p.reminder_service == ^bool)
    _, q -> q
  end)
end
```

## Flop Phoenix

[Flop Phoenix](https://hex.pm/packages/flop_phoenix) is a companion library that
defines view helpers for use in Phoenix templates.
