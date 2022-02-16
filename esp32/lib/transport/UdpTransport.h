#pragma once

#include "Transport.h"
#include "../../src/config.h"

class OutputBuffer;
class AsyncUDP;

class UdpTransport : public Transport
{
private:
  AsyncUDP *udp;
  // IPAddress multicastIP;
protected:
  void send(int target);

public:
  UdpTransport(OutputBuffer *output_buffer);
  bool begin() override;
};