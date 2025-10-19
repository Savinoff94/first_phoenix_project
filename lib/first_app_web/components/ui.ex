defmodule FirstAppWeb.UI do
  use Phoenix.Component
  use FirstAppWeb, :verified_routes

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

  # Props
  attr :player, :map, default: nil
  attr :login, :string, required: true
  attr :timer_running, :boolean, default: false
  attr :side, :string, values: ["left", "right"], default: "left"
  attr :role, :string, values: ["player", "spectator"]

  def player_card(assigns) do
    ~H"""
    <div
      class={[
        "p-2 rounded min-h-[100px] w-[250px] h-full flex flex-col",
      ]}
    >
      <div
        class={[
          "flex h-full gap-2",
          if(@side == "right", do: "flex-row-reverse")
        ]}
      >
        <%= if @player && @login == @player.login do %>
          <div class="mt-2 flex flex-col justify-center gap-2">
            <%= for {emoji, label} <- [{"🪨", "Rock"}, {"📄", "Paper"}, {"✂️", "Scissors"}] do %>
              <button
                phx-click="player_made_choice"
                phx-value-choice={label}
                disabled={!@timer_running}
                class={[
                  "px-3 py-2 rounded transition",
                  @timer_running && "bg-gray-200 hover:bg-gray-300" || "bg-gray-100 opacity-60 cursor-not-allowed"
                ]}
              >
                <%= emoji %> <%= label %>
              </button>
            <% end %>
          </div>
        <% end %>

        <p class="text-gray-600 italic flex justify-center items-center w-full h-full text-2xl relative">
          <img
            src={~p"/images/rock.svg"}
            width="72"
            class={[
              "absolute transition-opacity",
              is_allowed_to_see(@player, @login, @timer_running, @role) && @player && @player.selected == "Rock" && "block" || "hidden"
            ]}
          />
          <img
            src={~p"/images/paper.svg"}
            width="72"
            class={[
              "absolute transition-opacity",
              is_allowed_to_see(@player, @login, @timer_running, @role) && @player && @player.selected == "Paper" && "block" || "hidden"
            ]}
          />
          <img
            src={~p"/images/scissors.svg"}
            width="72"
            class={[
              "absolute transition-opacity",
              is_allowed_to_see(@player, @login, @timer_running, @role) && @player && @player.selected == "Scissors" && "block" || "hidden"
            ]}
          />
          <img
            src={~p"/images/user.svg"}
            width="72"
            class={[
              "absolute text-gray-400",
              is_allowed_to_see(@player, @login, @timer_running, @role) && @player && @player.selected in ["Rock", "Paper", "Scissors"] && "hidden" || "block"
            ]}
          />
        </p>
      </div>

      <p class="mt-2 text-center font-medium">
        <%= cond do
          is_nil(@player) -> "Waiting..."
          @player.login == @login -> "You"
          true -> @player.login
        end %>
      </p>
    </div>
    """
  end

  def is_allowed_to_see(player, login, timer_running, role) do
    cond do
      role == "spectator" ->
        true

      is_nil(player) ->
        false

      timer_running and login == player.login ->
        true

      timer_running ->
        false

      true ->
        true
    end
  end

end
