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
    taxis = select_candidate_taxis(request)
    Task.await(task)

    Process.send(self(), :block1, [:nosuspend])

    {:noreply, %{request: request, candidates: taxis, status: NotAccepted}}

  end

  def handle_info(:block1, %{request: request, candidates: taxis, status: NotAccepted} = state) do

    if taxis != [] do

      taxi = hd(taxis)
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

      Process.send_after(self(),:timeout1, 5000)

      {:noreply, %{request: request, candidates: tl(taxis), contacted_taxi: taxi, status: NotAccepted}}

    else

      %{"username" => username} = request
      IO.inspect(username )
      TaxiBeWeb.Endpoint.broadcast("customer:" <> username, "booking_request", %{msg: "No taxis found at this moment" })
      {:noreply, %{state | contacted_taxi: ""}}

    end

  end

  def handle_info(:timeout1, %{request: _request, contacted_taxi: _taxi, status: NotAccepted} = state) do
    IO.inspect(_taxi)
    %{nickname: nickname} = _taxi
    TaxiBeWeb.Endpoint.broadcast("driver:"<> nickname, "booking_request", %{msg: "Time out"})
    Process.send(self(), :block1, [:nosuspend])
    {:noreply, state}
  end

  def handle_info(:timeout1, %{request: _request, status: Accepted} = state) do
    {:noreply, state}
  end

  def handle_cast({:process_accept, driver_username}, %{request: request, contacted_taxi: contacted_taxi, status: NotAccepted} = state) do
    %{"pickup_address" => pickup_address} = request
    %{"username" => username} = request

    coord2 = TaxiBeWeb.Geolocator.geocode(pickup_address)
    IO.inspect(coord2)

    case coord2 do
      {:ok, coord2_list} ->
        taxi_coords = {contacted_taxi.latitude, contacted_taxi.longitude}
        {distance, duration} = TaxiBeWeb.Geolocator.distance_and_duration(taxi_coords, coord2_list)

        TaxiBeWeb.Endpoint.broadcast("customer:" <> username, "booking_request", %{msg: "Taxi is on the way. Estimated time: #{duration} minutes."})

        {:noreply, state |> Map.put(:status, Accepted)}

      {:error, _reason} ->
        TaxiBeWeb.Endpoint.broadcast("customer:" <> username, "booking_request", %{msg: "Could not find the coordinates of the pickup address."})
        {:noreply, state}
    end
  end

  def handle_cast({:process_accept, driver_username}, %{request: request, status: Accepted} = state) do
    {:noreply, state |> Map.put(:status, Accepted)}
  end

  def compute_ride_fare(request) do

    %{
      "pickup_address" => pickup_address,
      "dropoff_address" => dropoff_address
     } = request

    coord1 = TaxiBeWeb.Geolocator.geocode(pickup_address)
    coord2 = TaxiBeWeb.Geolocator.geocode(dropoff_address)
    IO.inspect(coord1)
    IO.inspect(coord2)
    {distance, duration} = TaxiBeWeb.Geolocator.distance_and_duration(coord1, coord2)
    {request, Float.ceil(distance/300), Float.ceil(duration / 110, 0)}

  end

  def notify_customer_ride_fare({request, fare, duration}) do

    %{"username" => customer} = request
    TaxiBeWeb.Endpoint.broadcast("customer:" <> customer, "booking_request", %{msg: "Ride fare: #{fare} \n Ride estimate time: #{duration}"})

  end

  def select_candidate_taxis(%{"pickup_address" => _pickup_address}) do

    [
      %{nickname: "frodo", latitude: 19.0319783, longitude: -98.2349368}, # Angelopolis
      %{nickname: "samwise", latitude: 19.0061167, longitude: -98.2697737}, # Arcangeles
      %{nickname: "merry", latitude: 19.0092933, longitude: -98.2473716} # Paseo Destino
    ]

  end

end
