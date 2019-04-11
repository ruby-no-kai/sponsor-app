import * as React from 'react';

import {TicketCheckinResult, checkin} from './CheckinClient';

interface Props {
  endpoint: string,
}

interface State {
  response: TicketCheckinResult | null,
  requested: boolean,
  requestError: string | null,
}

export default class ReceptionCheckinButton extends React.Component<Props, State> {

  constructor(props: Props) {
    super(props);
    this.state = {
      response: null,
      requested: false,
      requestError: null,
    }
  }

  public render() {
    let alertElem = null;
    if (this.state.response) {
      if (this.state.response.ok) {
        alertElem = <div className="alert alert-success"><b>Checked in</b></div>;
      } else {
        const errors = this.state.response.errors || [];
        alertElem = <div className="alert alert-danger">
            <p><b>Errors:</b></p>
            <ul>
              {errors.map((err, index) => <li key={index}>{err}</li>)}
            </ul>
          </div>;
      }
    }
    const errorAlert = this.state.requestError ? <div className='alert alert-danger'>Something went wrong: {this.state.requestError}</div> : null;
    const button = <button className='btn btn-primary btn-lg mb-2' onClick={this.onClick.bind(this)} disabled={this.state.requested}>Check In</button>
    return <div>
      {(this.state.response && this.state.response.ok) ? null: button}
      {errorAlert}
      {alertElem}
    </div>;
  }

  private onClick(e: React.MouseEvent<HTMLButtonElement>) {
    this.setState({requested: true, requestError: null});
    checkin(this.props.endpoint).then((resp) => {
      this.setState({response: resp, requested: false});
    }).catch((e) => {
      this.setState({requestError: e.toString(), requested: false});
      throw e;
    });
  }
}
