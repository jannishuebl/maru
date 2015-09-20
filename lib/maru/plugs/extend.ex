defmodule Maru.Plugs.Extend do
  alias Plug.Conn

  def init(opts) do
    router = opts |> Keyword.fetch! :at
    'Elixir.' ++ _ = Atom.to_char_list router
    version = opts |> Keyword.fetch! :version
    extend = opts |> Keyword.fetch! :extend
    only = opts |> Keyword.get :only, nil
    except = opts |> Keyword.get :except, nil
    unless is_nil(only) or is_nil(except) do
      raise ":only and :except are in conflict!"
    end
    {router, version, extend, only, except}
  end


  def call(%Conn{private: %{maru_version: v1}}=conn, {_router, v2, _extend, _only, _except}) when v1 != v2 do
    conn
  end

  def call(conn, {router, _version, extend, nil, nil}) do
    try_extend(conn, router, extend)
  end

  def call(%Conn{method: method, private: %{maru_resource_path: path}}=conn, {router, _version, extend, only, nil}) do
    only |> Enum.any?(fn {m, p} ->
      method_match?(method, m) and path_match?(path, p)
    end)
 |> case do
      true -> try_extend(conn, router, extend)
      false -> conn
    end
  end

  def call(%Conn{method: method, private: %{maru_resource_path: path}}=conn, {router, _version, extend, nil, except}) do
    except |> Enum.any?(fn {m, p} ->
      method_match?(method, m) and path_match?(path, p)
    end)
 |> case do
      true -> conn
      false -> try_extend(conn, router, extend)
    end
  end


  defp method_match?(_m, :match) do
    true
  end

  defp method_match?(m1, m2) do
    m1 == m2 |> to_string |> String.upcase
  end


  defp path_match?(p1, p2) do
    lstrip(p1, p2 |> Maru.Router.Path.split)
  end

  defp lstrip([], []),                         do: true
  defp lstrip(_rest, ["*"]),                   do: true
  defp lstrip([h|t1], [h|t2]),                 do: lstrip(t1, t2)
  defp lstrip([_|t1], [h|t2]) when is_atom(h), do: lstrip(t1, t2)
  defp lstrip(_, _),                           do: false


  defp try_extend(conn_orig, router, extend) do
    conn_orig
 |> Conn.put_private(:maru_version, extend)
 |> router.call([])
 |> case do
      %Conn{halted: true} = conn -> conn
      %Conn{}                    -> conn_orig
    end
  end

end