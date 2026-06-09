#include "unity.h"

#include "usb_bridge_protocol.h"

void test_usb_bridge_parse_defaults_to_ble_without_slot(void)
{
    int scanner_id = -1;
    const char *json = NULL;

    fof_usb_bridge_parse_result_t rc =
        fof_usb_bridge_parse_scanner_rx_payload("{\"type\":\"status\"}", &scanner_id, &json);

    TEST_ASSERT_EQUAL(FOF_USB_BRIDGE_PARSE_OK, rc);
    TEST_ASSERT_EQUAL_INT(0, scanner_id);
    TEST_ASSERT_EQUAL_STRING("{\"type\":\"status\"}", json);
}

void test_usb_bridge_parse_wifi_slot_name_maps_to_wifi(void)
{
    int scanner_id = -1;
    const char *json = NULL;

    fof_usb_bridge_parse_result_t rc =
        fof_usb_bridge_parse_scanner_rx_payload("wifi:{\"type\":\"detection\"}", &scanner_id, &json);

    TEST_ASSERT_EQUAL(FOF_USB_BRIDGE_PARSE_OK, rc);
    TEST_ASSERT_EQUAL_INT(1, scanner_id);
    TEST_ASSERT_EQUAL_STRING("{\"type\":\"detection\"}", json);
}

void test_usb_bridge_parse_numeric_slot_one_maps_to_wifi(void)
{
    int scanner_id = -1;
    const char *json = NULL;

    fof_usb_bridge_parse_result_t rc =
        fof_usb_bridge_parse_scanner_rx_payload("1:{\"type\":\"scanner_info\"}", &scanner_id, &json);

    TEST_ASSERT_EQUAL(FOF_USB_BRIDGE_PARSE_OK, rc);
    TEST_ASSERT_EQUAL_INT(1, scanner_id);
    TEST_ASSERT_EQUAL_STRING("{\"type\":\"scanner_info\"}", json);
}

void test_usb_bridge_parse_ble_slot_name_maps_to_ble(void)
{
    int scanner_id = -1;
    const char *json = NULL;

    fof_usb_bridge_parse_result_t rc =
        fof_usb_bridge_parse_scanner_rx_payload("ble:{\"type\":\"status\"}", &scanner_id, &json);

    TEST_ASSERT_EQUAL(FOF_USB_BRIDGE_PARSE_OK, rc);
    TEST_ASSERT_EQUAL_INT(0, scanner_id);
    TEST_ASSERT_EQUAL_STRING("{\"type\":\"status\"}", json);
}

void test_usb_bridge_parse_rejects_unknown_slot(void)
{
    int scanner_id = -1;
    const char *json = NULL;

    fof_usb_bridge_parse_result_t rc =
        fof_usb_bridge_parse_scanner_rx_payload("foo:{\"type\":\"status\"}", &scanner_id, &json);

    TEST_ASSERT_EQUAL(FOF_USB_BRIDGE_PARSE_BAD_SLOT, rc);
}

void test_usb_bridge_parse_rejects_empty_slot(void)
{
    int scanner_id = -1;
    const char *json = NULL;

    fof_usb_bridge_parse_result_t rc =
        fof_usb_bridge_parse_scanner_rx_payload(":{\"type\":\"status\"}", &scanner_id, &json);

    TEST_ASSERT_EQUAL(FOF_USB_BRIDGE_PARSE_BAD_SLOT, rc);
}

void test_usb_bridge_parse_rejects_empty_json_after_slot(void)
{
    int scanner_id = -1;
    const char *json = NULL;

    fof_usb_bridge_parse_result_t rc =
        fof_usb_bridge_parse_scanner_rx_payload("wifi:   \t", &scanner_id, &json);

    TEST_ASSERT_EQUAL(FOF_USB_BRIDGE_PARSE_EMPTY, rc);
}
