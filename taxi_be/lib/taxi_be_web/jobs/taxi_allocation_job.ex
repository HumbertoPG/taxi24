defmodule TaxiBeWeb.TaxiAllocationJob do
  use GenServer

  def start_link(request, name) do
    GenServer.start_link(__MODULE__, request, name: name)
  end

  def init(request) do
    Process.send(self(), :step1, [:nosuspend])
    {:ok, %{request: request}}
  end

  def handle_info(:step1, %{request: request}) do

    taxi = Enum.take_random(candidate_taxis(), 1) |> hd()

    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address,
      "booking_id" => booking_id
    } = request
    TaxiBeWeb.Endpoint.broadcast(
      "driver:" <> taxi.nickname,
      "booking_request",
       %{
         msg: "Viaje de '#{pickup_address}' a '#{dropoff_address}'",
         bookingId: booking_id
        })

    Process.send_after(self(), :timeout1, 10000)

    {:noreply, %{request: request, contacted_taxi: taxi}}

  end

  def handle_info(:timeout1, %{request: request, contacted_taxi: taxi = state}) do

    %{"username" => customer} = request
    %{nickname: nickname} = taxi


    TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request", %{msg: "Any taxi was fount at this moment"})
    TaxiBeWeb.Endpoint.broadcast("driver:" <> nickname, "booking_request", %{msg: "Time out"})
    {:noreply, state}

  end

  def handle_cast({:process_accept, driver_username}, %{request: request = state}) do

    %{"username" => username} = request
    compute_ride_arrival_time(request) |> notify_customer_ride_arrival_time()

    {:noreply, state}

  end

  def compute_ride_arrival_time(request) do

    %{"pickup_address" => pickup_address, "dropoff_address" => dropoff_address} = request

    coord1 = TaxiBeWeb.Geolocator.geocode(pickup_address)
    coord2 = TaxiBeWeb.Geolocator.geocode(dropoff_address)

    {distance, _duration} = TaxiBeWeb.Geolocator.distance_and_duration(coord1, coord2)
    {request, Float.ceil(distance/80)}

  end

  def notify_customer_ride_arrival_time({request, time}) do

    %{"username" => customer} = request
    %{"driver" => driver} = request
    TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request", %{msg: "Your taxi will arrives at: #{time} minutes" })

  end

  def candidate_taxis() do
    [
      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368}, # Angelopolis
      %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737}, # Arcangeles
      %{nickname: "merry", latitude: 19.0092933, longitude: -98.2473716} # Paseo Destino
    ]
  end
end
