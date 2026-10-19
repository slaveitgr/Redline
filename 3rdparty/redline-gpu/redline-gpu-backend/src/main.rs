// SPDX-License-Identifier: MIT
// Redline transport for the vendored LACT GPU engine.
use std::{io::{self, BufRead, BufReader, Write}, os::unix::net::UnixStream};
fn main() -> anyhow::Result<()> {
    let readonly = std::env::args().any(|a| a == "--read-only");
    let (mut client, server) = UnixStream::pair()?;
    server.set_nonblocking(true)?;
    let worker = std::thread::spawn(move || lact_daemon::run_embedded(server));
    let mut replies = BufReader::new(client.try_clone()?);
    let mut output = io::stdout().lock();
    for line in io::stdin().lock().lines() {
        let line = line?;
        let request: serde_json::Value = serde_json::from_str(&line)?;
        let command = request["command"].as_str().unwrap_or("");
        let read = matches!(command, "ping"|"system_info"|"list_devices"|"device_info"|"device_stats"|"device_clocks_info"|"device_api_info"|"device_power_profile_modes"|"get_power_states"|"get_gpu_config"|"list_profiles"|"get_profile");
        let write=matches!(command,"set_gpu_config"|"confirm_pending_config");
        if (!read && !write) || (readonly && !read) {
            writeln!(output, "{{\"status\":\"error\",\"data\":\"Command is unavailable for this connection\"}}")?;
            output.flush()?;continue;
        }
        writeln!(client, "{line}")?;
        let mut response=String::new();
        if replies.read_line(&mut response)? == 0 {break;}
        output.write_all(response.as_bytes())?;output.flush()?;
    }
    drop(replies);drop(client);
    worker.join().map_err(|_|anyhow::anyhow!("GPU worker stopped unexpectedly"))??;
    Ok(())
}
