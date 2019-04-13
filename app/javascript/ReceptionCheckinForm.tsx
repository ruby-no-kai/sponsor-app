import * as React from 'react';

import {TicketCheckinResult, checkin} from './CheckinClient';

interface Props {
  endpoint: string,
}

interface State {
  response: TicketCheckinResult | null,
  requested: boolean,
  requestError: string | null,
  code: string,
}

export default class ReceptionCheckinForm extends React.Component<Props, State> {
  private inputRef: React.RefObject<HTMLInputElement>;
  constructor(props: Props) {
    super(props);
    this.state = {
      response: null,
      requested: false,
      requestError: null,
      code: '',
    };
    this.inputRef = React.createRef();
  }

  public render() {
    return <div>
      {this.renderForm()}
      {this.renderTicket()}
      {this.renderResult()}
    </div>;
  }

  public renderForm() {
    return <div className='mb-3'>
      <form action="#" onSubmit={this.onSubmit.bind(this)} className='form-inline'>
        <fieldset disabled={this.state.requested} >
          <input value={this.state.code} onChange={this.onChange.bind(this)} ref={this.inputRef} className='form-control' placeholder='Code, or URL' />
          <button className='btn btn-primary'>Check In</button>
        </fieldset>
      </form>
    </div>;
  }

  public renderTicket() {
    if (!(this.state.response && this.state.response.ticket)) return null;
    const ticket = this.state.response.ticket;
    return <div className='card mt-2'>
      <div className='card-body'>
        <div className='d-flex justify-content-between'>
          <div>
            <code>{ticket.code}</code>-<code>{ticket.id}</code>
          </div>
          <div>{ticket.conference}</div>
        </div>
        <div className='text-center my-2'>
          <p style={{fontSize: '26pt'}}><strong>{ticket.name}</strong></p>
          <small style={{fontSize: '18pt'}}>{ticket.sponsor}</small>
          <p style={{fontSize: '14pt'}}><span className='badge badge-info'>{ticket.kind}</span></p>
        </div>
      </div>
    </div>
  }

  public renderResult() {
    if (this.state.response) {
      if (this.state.response.ok) {
        return <div className="alert alert-success"><b>Checked in</b></div>;
      } else {
        const errors = this.state.response.errors || [];
        return <div className="alert alert-danger">
            <p><b>Errors:</b></p>
            <ul>
              {errors.map((err, index) => <li key={index}>{err}</li>)}
            </ul>
          </div>;
      }
    }
    return null;
  }

  private onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    this.setState({requested: true, requestError: null});
    const code = this.state.code.replace(/^.+\//, '');
    checkin(`${this.props.endpoint}/${code}`).then((resp) => {
      this.setState({response: resp, requested: false, code: ''});
      if (this.inputRef.current) this.inputRef.current.focus();
    }).catch((e) => {
      this.setState({requestError: e.toString(), requested: false});
      if (this.inputRef.current) this.inputRef.current.focus();
      throw e;
    });
  }

  private onChange(e: React.ChangeEvent<HTMLInputElement>) {
    this.setState({code: e.target.value});
  }
}
