import gleam/otp/supervisor.{ApplicationStartMode, ErlangStartResult}
import gleam/otp/actor.{Continue, Ready, Spec}
import gleam/otp/process.{Sender}
import gleam/option.{None, Some}
import gleam/dynamic.{Dynamic}
import gleam/io

pub fn start(
  _mode: ApplicationStartMode,
  _args: List(Dynamic),
) -> ErlangStartResult {
  init
  |> supervisor.start
  |> supervisor.to_erlang_start_result
}

pub fn stop(_state: Dynamic) {
  supervisor.application_stopped()
}

fn init(children) {
  children
  |> supervisor.add(supervisor.worker(fn(_) {
    actor.start_spec(Spec(pinger_init, 1000, pinger_loop))
  }))
}

type PingerState {
  Pinger(pong_sender: Sender(PongChannelMsg))
}

type PingChannelMsg {
  Ping
}

fn pinger_init() {
  io.debug("Pinger starting!")
  assert #(ping_sender, ping_receiver) = process.new_channel()
  assert Ok(pong_sender) =
    actor.start_spec(Spec(ponger_init(ping_sender), 500, ponger_loop))
  process.send_after(ping_sender, 1000, Ping)
  Ready(Pinger(pong_sender), Some(ping_receiver))
}

fn pinger_loop(ping_msg, pinger_state) {
  case ping_msg {
    Ping -> {
      io.debug("Ping!")
      process.send_after(pinger_state.pong_sender, 1000, Pong)
      Continue(pinger_state)
    }
  }
}

type PongerState {
  Ponger(ping_sender: Sender(PingChannelMsg))
}

type PongChannelMsg {
  Pong
}

fn ponger_init(ping_sender) {
  fn() {
    io.debug("Ponger starting!")
    assert #(pong_sender, pong_receiver) = process.new_channel()
    Ready(Ponger(ping_sender), Some(pong_receiver))
  }
}

fn ponger_loop(pong_msg, ponger_state) {
  case pong_msg {
    Pong -> {
      io.debug("Pong!")
      process.send_after(ponger_state.ping_sender, 1000, Ping)
      Continue(ponger_state)
    }
  }
}
