#include <Arduino.h>
#include <AsyncUDP.h>
#include "UdpTransport.h"

#include "../../src/Application.h"
#include "../audio_output/OutputBuffer.h"

const int MAX_UDP_SIZE = 1436;
extern Application *application;


UdpTransport::UdpTransport(OutputBuffer *output_buffer) : Transport(output_buffer, MAX_UDP_SIZE)
{
/*
  if(!(multicastIP.fromString(MULTICAST_IP))) {
    Serial.printf("Invalid multicast IP: %s\n", MULTICAST_IP);
  } else {
    Serial.printf("Using %s for multicast UDP\n", MULTICAST_IP);
  }
*/
}

bool UdpTransport::begin()
{
  udp = new AsyncUDP();

  if (udp->listen(UDP_PORT)) // can be any other port, not necessarily same as broadcast port.
  {
    udp->onPacket([this](AsyncUDPPacket packet)
                  {
                    uint8_t header = packet.data()[0];
                    Serial.printf("Recived packet remoteIP %s, localIP %s, len %d, header = 0x%x\n", packet.remoteIP().toString().c_str(),
                                  packet.localIP().toString().c_str(), packet.length(), header);

                    // our packets contain unsigned 8 bit PCM samples
                    // so we can push them straight into the output buffer
                    // also check the target of the packet from the header
                    if ((packet.length() > this->m_header_size) && (packet.length() <= MAX_UDP_SIZE) && (application->is_for_me(header))) {
                      // check if it is a configuration packet
                      if (header & 0x80) {
                        update_device_colors(packet.data()[1], packet.data()[2], packet.data()[3], packet.data()[4]);
                      }
                      // add samples only if we are not talking right now (all buttons not pushed)
                      else if (digitalRead(GPIO_TRANSMIT_BUTTON_BROADCAST) && digitalRead(GPIO_TRANSMIT_BUTTON_APP) && digitalRead(GPIO_TRANSMIT_BUTTON_ESP)) {
                        this->m_output_buffer->add_samples(packet.data() + m_header_size, packet.length() - m_header_size);
                        turn_led_on((packet.data()[0] & 0xc) >> 2);
                        // this is for QA - write directly to the buffer
                        // application->m_output->write((int16_t *)packet.data(), packet.length());
                      }
                    }
                  });
    return true;
  }

  Serial.println("Failed to listen");
  return false;
}

void UdpTransport::send(int target)
{
  // Serial.printf("UdpTransport::send to %d\n", target);
  // add the target to the header
  if (m_header_size != 0)
    m_buffer[0] |= target;
  udp->broadcast(m_buffer, m_index);
  if (m_header_size != 0)
    m_buffer[0] &= ~target;
  /*
  if (target == GPIO_TRANSMIT_BUTTON_BROADCAST) {
    udp->broadcastTo(m_buffer, m_index, UDP_PORT_ESP_OTHER);
    udp->broadcastTo(m_buffer, m_index, UDP_PORT_APP);
  } 
  else if (target == GPIO_TRANSMIT_BUTTON_ESP) {
    udp->broadcastTo(m_buffer, m_index, UDP_PORT_ESP_OTHER);
  }
  else if (target == GPIO_TRANSMIT_BUTTON_APP) {
    udp->broadcastTo(m_buffer, m_index, UDP_PORT_APP);
  }
*/
}
