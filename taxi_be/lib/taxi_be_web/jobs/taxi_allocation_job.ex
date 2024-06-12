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

    task = Task.async(fn -> compute_ride_fare(request) |> notify_customer_ride_fare() end)
    Task.await(task)

    taxis = candidate_taxis()

    Enum.map(candidate_taxis(), fn taxi ->

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

    end)

    Process.send_after(self(), :timeout1, 10000)

    {:noreply, %{request: request, candidates: taxis, status: Waiting}}

  end

  def handle_info(:timeout1, %{request: request, candidates: taxis, status: Waiting} = state) do

    %{"username" => username} = request
    IO.inspect(username)
    IO.inspect(taxis)

    TaxiBeWeb.Endpoint.broadcast("customer:" <> username, "booking_request", %{msg: "Any taxi was found at thi moment"})

    Enum.map(taxis, fn taxi ->

      TaxiBeWeb.Endpoint.broadcast("driver:" <> taxi.nickname, "booking_request", %{msg: "Time out"})

    end)

    {:noreply, state}

  end

  def handle_info(:timeout1, %{request: request, candidates: taxis, status: Accepted} = state) do
    {:noreply, state}
  end

  def handle_cast({:process_accept, driver_username}, %{request: request, candidates: taxis, status: Waiting} = state) do

    taxi = Enum.find(taxis, fn taxi -> taxi.nickname == driver_username end)

    %{"pickup_address" => pickup_address} = request

    coord1 = TaxiBeWeb.Geolocator.geocode(pickup_address)
    coord2 = {:ok, [taxi.longitude, taxi.latitude]}

    {distance, duration} = TaxiBeWeb.Geolocator.distance_and_duration(coord1, coord2)

    %{"username" => username} = request
    TaxiBeWeb.Endpoint.broadcast("customer:" <> username, "booking_request", %{msg: "#{driver_username} is on the way. Estimate time for arrival: #{Float.ceil(duration / 60, 1)} minutes"})

    {:noreply, state |> Map.put(:status, Accepted)}

  end

  def handle_cast({:process_accept, driver_username}, %{request: request, candidates: taxis, status: Accepted} = state) do

    {:noreply, state}

  end

  def handle_cast({:process_reject, driver_username}, state) do

    {:noreply, state}

  end

  def compute_ride_fare(request) do

    %{"pickup_address" => pickup_address, "dropoff_address" => dropoff_address} = request

    coord1 = TaxiBeWeb.Geolocator.geocode(pickup_address)
    coord2 = TaxiBeWeb.Geolocator.geocode(dropoff_address)

    {distance, duration} = TaxiBeWeb.Geolocator.distance_and_duration(coord1, coord2)
    {request, Float.ceil(distance/80), duration}

  end

  def notify_customer_ride_fare({request, fare, duration}) do

    %{"username" => customer} = request

    TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request", %{msg: "Ride fare: #{fare}. Ride estimated time: #{duration}"})

  end

  def candidate_taxis() do
    [

      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368}, # Angelopolis
      %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737}, # Arcangeles
      %{nickname: "merry", latitude: 19.0092933, longitude: -98.2473716} # Paseo Destino

    ]
  end
end
