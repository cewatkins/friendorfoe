#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    FOF_TRANSPORT_NONE = 0,
    FOF_TRANSPORT_UART = 1,
    FOF_TRANSPORT_USB_CDC = 2,
} fof_transport_t;

typedef struct {
    fof_transport_t desired;
    fof_transport_t active;
    bool uart_fallback_enabled;
    bool fallback_active;
    uint32_t tx_error_count;
    uint32_t rx_error_count;
    uint32_t heartbeat_count;
    int64_t last_ok_ms;
} fof_transport_state_t;

const char *fof_transport_name(fof_transport_t transport);

void fof_transport_state_init(fof_transport_state_t *state,
                              bool usb_primary,
                              bool uart_fallback_enabled,
                              bool usb_ready,
                              bool uart_ready,
                              int64_t now_ms);

bool fof_transport_state_try_activate_usb(fof_transport_state_t *state,
                                          bool usb_ready);

void fof_transport_state_note_tx(fof_transport_state_t *state,
                                 bool success,
                                 int64_t now_ms);

void fof_transport_state_note_rx(fof_transport_state_t *state,
                                 bool success,
                                 int64_t now_ms);

void fof_transport_state_note_heartbeat(fof_transport_state_t *state);

#ifdef __cplusplus
}
#endif
