import React, {useEffect, useState} from 'react';
import Button from '@mui/material/Button';
import socket from '../services/taxi_socket';
import { Card, CardContent, Grid, Typography } from '@mui/material';

function Driver(props) {
  let [message, setMessage] = useState();
  let [bookingId, setBookingId] = useState();
  let [visible, setVisible] = useState(false);
  let [accepted, setAccepted] = useState(false);
  let [arrivalNotified, setArrivalNotified] = useState(false);

  useEffect(() => {
    let channel = socket.channel("driver:" + props.username, {token: "123"});
    channel.on("booking_request", data => {
      console.log("Received", data);
      setMessage(data.msg);
      setBookingId(data.bookingId);
      setVisible(true);
    });
    channel.join();
  },[props]);

  let reply = (decision) => {
    fetch(`http://localhost:4000/api/bookings/${bookingId}`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({action: decision, username: props.username})
    }).then(resp => {
      if (decision === "accept") {
        setAccepted(true);
      }
      setVisible(false);
    });
  };

  let notifyArrival = () => {
    fetch(`http://localhost:4000/api/bookings/${bookingId}`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({action: "notify_arrival", username: props.username})
    }).then(resp => setArrivalNotified(true));
  };

  let startTrip = () => {
    fetch(`http://localhost:4000/api/bookings/${bookingId}`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({action: "start_trip", username: props.username})
    }).then(resp => setArrivalNotified(false));
  };

  return (
    <div style={{textAlign: "center", borderStyle: "solid"}}>
        Driver: {props.username}
        <Grid container justifyContent="center" alignItems="center">
          <Grid item xl="2" container justifyContent="center">
            {accepted && !arrivalNotified && (
              <Button onClick={notifyArrival} variant="outlined" color="secondary">Notify arrival</Button>
            )}
            {arrivalNotified && (
              <Button onClick={startTrip} variant="outlined" color="primary">Start Trip</Button>
            )}
          </Grid>
          <Grid item style={{backgroundColor: "lavender", height: "100px"}} xl="10" container justifyContent="center" alignItems="center">
            {
              visible ?
              <Card variant="outlined" style={{margin: "auto", width: "600px"}}>
                <CardContent>
                  <Typography>
                    {message}
                  </Typography>
                </CardContent>
                <Grid container justifyContent="center" spacing={2}>
                  <Grid item>
                    <Button onClick={() => reply("accept")} variant="outlined" color="primary">Accept</Button>
                  </Grid>
                  <Grid item>
                    <Button onClick={() => reply("reject")} variant="outlined" color="secondary">Reject</Button>
                  </Grid>
                </Grid>
              </Card> :
              null
            }
          </Grid>
        </Grid>
    </div>
  );
}

export default Driver;
