#include "unity.h"

#include "transport_link.h"

void test_scanner_online_offline_over_usb(void)
{
    fof_transport_state_t state = {0};
    fof_transport_state_init(&state, true, true, true, true, 1000);
    TEST_ASSERT_EQUAL(FOF_TRANSPORT_USB_CDC, state.active);

    /* Scanner offline -> USB unavailable -> fallback to UART path. */
    fof_transport_state_init(&state, true, true, false, true, 2000);
    TEST_ASSERT_EQUAL(FOF_TRANSPORT_UART, state.active);
    TEST_ASSERT_TRUE(state.fallback_active);
}

void test_uplink_restart_with_scanner_attached(void)
{
    fof_transport_state_t state = {0};

    /* Uplink reboot with scanner still connected should reacquire USB primary. */
    fof_transport_state_init(&state, true, true, true, true, 1000);
    TEST_ASSERT_EQUAL(FOF_TRANSPORT_USB_CDC, state.active);

    fof_transport_state_note_tx(&state, true, 1500);
    TEST_ASSERT_EQUAL_INT64(1500, state.last_ok_ms);
}

void test_usb_replug_reconnect_behavior(void)
{
    fof_transport_state_t state = {0};
    fof_transport_state_init(&state, true, true, false, true, 1000);
    TEST_ASSERT_EQUAL(FOF_TRANSPORT_UART, state.active);

    TEST_ASSERT_TRUE(fof_transport_state_try_activate_usb(&state, true));
    TEST_ASSERT_EQUAL(FOF_TRANSPORT_USB_CDC, state.active);
    TEST_ASSERT_FALSE(state.fallback_active);
}

void test_uart_fallback_when_usb_path_unavailable(void)
{
    fof_transport_state_t state = {0};
    fof_transport_state_init(&state, true, true, false, true, 1000);

    TEST_ASSERT_EQUAL(FOF_TRANSPORT_UART, state.active);
    TEST_ASSERT_TRUE(state.fallback_active);
    TEST_ASSERT_EQUAL_STRING("uart", fof_transport_name(state.active));
}
