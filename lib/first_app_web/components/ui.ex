defmodule FirstAppWeb.UI do
  use Phoenix.Component

  def table_header_col(assigns) do
    ~H"""
    <th class={["px-6 py-3 w-fit max-w-[200px] text-left align-top"]}>
      <div class="flex w-fit items-center gap-2">
        <%= render_slot(@inner_block) %>
      </div>
    </th>
    """
  end

  def table_styled(assigns) do
    ~H"""
    <div class="flex justify-center w-full">
      <div class="relative w-fit min-w-[70%] overflow-x-auto shadow-lg sm:rounded-lg">
        <table class="w-full text-sm text-left rtl:text-right text-gray-500 dark:text-gray-400">
          <%= render_slot(@inner_block) %>
        </table>
      </div>
    </div>
    """
  end
  def thead_styled(assigns) do
    ~H"""
    <thead class="text-xs text-gray-900 uppercase bg-gray-50 dark:bg-gray-900 dark:text-gray-400">
      <%= render_slot(@inner_block) %>
    </thead>
    """
  end
  def tr_styled(assigns) do
    ~H"""
    <tr class="bg-white border-b dark:bg-gray-900 dark:border-gray-800 border-gray-300 hover:bg-gray-50 dark:hover:bg-gray-600">
      <%= render_slot(@inner_block) %>
    </tr>
    """
  end
  def td_styled(assigns) do
    ~H"""
    <td class="px-6 py-3">
      <%= render_slot(@inner_block) %>
    </td>
    """
  end

end
