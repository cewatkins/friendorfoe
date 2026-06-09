#include "usb_bridge_protocol.h"

#include <string.h>

fof_usb_bridge_parse_result_t fof_usb_bridge_parse_scanner_rx_payload(
    const char *payload,
    int *scanner_id_out,
    const char **json_out)
{
    if (!payload || !scanner_id_out || !json_out) {
        return FOF_USB_BRIDGE_PARSE_EMPTY;
    }

    int scanner_id = 0;
    const char *json = payload;

    while (*json == ' ' || *json == '\t') {
        json++;
    }
    if (*json == '\0') {
        return FOF_USB_BRIDGE_PARSE_EMPTY;
    }

    /* Bare JSON payload: default to BLE slot routing. */
    if (*json == '{') {
        *scanner_id_out = scanner_id;
        *json_out = json;
        return FOF_USB_BRIDGE_PARSE_OK;
    }

    const char *sep = strchr(json, ':');

    if (sep) {
        size_t slot_len = (size_t)(sep - json);
        if (slot_len == 0) {
            return FOF_USB_BRIDGE_PARSE_BAD_SLOT;
        }
        if ((slot_len == 3 && strncmp(json, "ble", 3) == 0) ||
            (slot_len == 1 && json[0] == '0')) {
            scanner_id = 0;
        } else if ((slot_len == 4 && strncmp(json, "wifi", 4) == 0) ||
                   (slot_len == 1 && json[0] == '1')) {
            scanner_id = 1;
        } else {
            return FOF_USB_BRIDGE_PARSE_BAD_SLOT;
        }
        json = sep + 1;
    } else {
        return FOF_USB_BRIDGE_PARSE_BAD_SLOT;
    }

    while (*json == ' ' || *json == '\t') {
        json++;
    }
    if (*json == '\0') {
        return FOF_USB_BRIDGE_PARSE_EMPTY;
    }

    *scanner_id_out = scanner_id;
    *json_out = json;
    return FOF_USB_BRIDGE_PARSE_OK;
}
