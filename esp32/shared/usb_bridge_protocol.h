#ifndef FOF_USB_BRIDGE_PROTOCOL_H
#define FOF_USB_BRIDGE_PROTOCOL_H

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    FOF_USB_BRIDGE_PARSE_OK = 0,
    FOF_USB_BRIDGE_PARSE_EMPTY,
    FOF_USB_BRIDGE_PARSE_BAD_SLOT
} fof_usb_bridge_parse_result_t;

/**
 * Parse payload after "FOF_SCANNER_RX:".
 *
 * Accepted forms:
 * - "{...json...}" (defaults to BLE slot 0)
 * - "ble:{...json...}" / "0:{...json...}"
 * - "wifi:{...json...}" / "1:{...json...}"
 */
fof_usb_bridge_parse_result_t fof_usb_bridge_parse_scanner_rx_payload(
    const char *payload,
    int *scanner_id_out,
    const char **json_out);

#ifdef __cplusplus
}
#endif

#endif
