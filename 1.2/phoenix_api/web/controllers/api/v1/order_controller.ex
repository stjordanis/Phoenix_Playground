defmodule PhoenixApi.Api.V1.OrderController do
  use PhoenixApi.Web, :controller

  alias PhoenixApi.Order
  alias PhoenixApi.OrderProduct
  alias PhoenixApi.EventManager

  plug Guardian.Plug.EnsureAuthenticated, [handler: __MODULE__]  when action in [:create, :show]
  plug :scrub_params, "order" when action in [:create]

  def create(conn, %{"order" => order_params}) do
    user = Guardian.Plug.current_resource(conn)
    changeset =
        user
        |> build_assoc(:orders)
        |> Order.changeset(%{total: calcualte_total(order_params)})

    case Repo.insert(changeset) do
      {:ok, order} ->
        conn
        |> populate_order_products(order, order_params)

        order = order |> Repo.preload(order_products: :product)

        # notify event
        EventManager.notify(:order_confirmation, %{user: user, order: order})

        conn
        |> put_status(:created)
        |> put_resp_header("location", order_path(conn, :show, order))
        |> json(%{data: %{id: order.id, total: order.total, product_ids: order_params["product_ids"]}})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(PhoenixApi.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    order = Repo.get!(Order, id) |> Repo.preload(order_products: :product)
    PhoenixETag.render_if_stale(conn, :show, order: order)
  end

  defp calcualte_total(%{"product_ids" => ids}) do
      query = from p in "products",
              select: p.price,
              where: p.id in ^ids
      Repo.all(query)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  defp populate_order_products(conn, order, %{"product_ids" => ids}) do
      query = from p in "products",
              select: p.id,
              where: p.id in ^ids
      Repo.all(query)
      |> Enum.each(fn(product_id) ->
          changeset = OrderProduct.changeset(%OrderProduct{}, %{order_id: order.id, product_id: product_id})
          case Repo.insert(changeset) do
              {:ok, _} -> conn
              {:error, changeset} ->
                  conn
                  |> put_status(:unprocessable_entity)
                  |> render(PhoenixApi.ChangesetView, "error.json", changeset: changeset)
            end
      end)
  end

  def unauthenticated(conn, _params) do
    conn
    |> put_status(:unauthorized)
    |> json(%{message: "Authentication required", error: :unauthorized})
  end
end
