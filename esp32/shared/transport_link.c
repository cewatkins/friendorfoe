#include "transport_link.h"

#include <string.h>

const char *fof_transport_name(fof_transport_t transport)
{
    switch (transport) {
        case FOF_TRANSPORT_UART:
            return "uart";
        case FOF_TRANSPORT_USB_CDC:
            return "usb";
        default:
            return "none";
    }
}

void fof_transport_state_init(fof_transport_state_t *state,
                              bool usb_primary,
                              bool uart_fallback_enabled,
                              bool usb_ready,
                              bool uart_ready,
                              int64_t now_ms)
{
    if (!state) {
        return;
    }

    memset(state, 0, sizeof(*state));
    state->desired = usb_primary ? FOF_TRANSPORT_USB_CDC : FOF_TRANSPORT_UART;
    state->uart_fallback_enabled = uart_fallback_enabled;

    if (state->desired == FOF_TRANSPORT_USB_CDC && usb_ready) {
        state->active = FOF_TRANSPORT_USB_CDC;
    } else if ((state->desired == FOF_TRANSPORT_UART && uart_ready) ||
               (state->desired == FOF_TRANSPORT_USB_CDC && uart_fallback_enabled && uart_ready)) {
        state->active = FOF_TRANSPORT_UART;
        state->fallback_active = (state->desired == FOF_TRANSPORT_USB_CDC);
    } else {
        state->active = FOF_TRANSPORT_NONE;
    }

    state->last_ok_ms = now_ms;
}

bool fof_transport_state_try_activate_usb(fof_transport_state_t *state,
                                          bool usb_ready)
{
    if (!state || !usb_ready || state->desired != FOF_TRANSPORT_USB_CDC) {
        return false;
    }
    if (state->active == FOF_TRANSPORT_USB_CDC) {
        return true;
    }
    state->active = FOF_TRANSPORT_USB_CDC;
    state->fallback_active = false;
    return true;
}

void fof_transport_state_note_tx(fof_transport_state_t *state,
                                 bool success,
                                 int64_t now_ms)
{
    if (!state) {
        return;
    }
    if (success) {
        state->last_ok_ms = now_ms;
    } else {
        state->tx_error_count++;
    }
}

void fof_transport_state_note_rx(fof_transport_state_t *state,
                                 bool success,
                                 int64_t now_ms)
{
    if (!state) {
        return;
    }
    if (success) {
        state->last_ok_ms = now_ms;
    } else {
        state->rx_error_count++;
    }
}

void fof_transport_state_note_heartbeat(fof_transport_state_t *state)
{
    if (!state) {
        return;
    }
    state->heartbeat_count++;
}
