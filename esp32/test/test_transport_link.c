#include "unity.h"

#include "transport_link.h"

void test_transport_prefers_usb_when_ready(void)
{
    fof_transport_state_t state = {0};
    fof_transport_state_init(&state, true, true, true, true, 1234);

    TEST_ASSERT_EQUAL(FOF_TRANSPORT_USB_CDC, state.active);
    TEST_ASSERT_FALSE(state.fallback_active);
    TEST_ASSERT_EQUAL_STRING("usb", fof_transport_name(state.active));
}

void test_transport_falls_back_to_uart_when_usb_unavailable(void)
{
    fof_transport_state_t state = {0};
    fof_transport_state_init(&state, true, true, false, true, 1234);

    TEST_ASSERT_EQUAL(FOF_TRANSPORT_UART, state.active);
    TEST_ASSERT_TRUE(state.fallback_active);
}

void test_transport_switches_to_usb_after_reconnect(void)
{
    fof_transport_state_t state = {0};
    fof_transport_state_init(&state, true, true, false, true, 1234);

    TEST_ASSERT_TRUE(fof_transport_state_try_activate_usb(&state, true));
    TEST_ASSERT_EQUAL(FOF_TRANSPORT_USB_CDC, state.active);
    TEST_ASSERT_FALSE(state.fallback_active);
}

void test_transport_error_counters_and_heartbeat(void)
{
    fof_transport_state_t state = {0};
    fof_transport_state_init(&state, false, true, false, true, 1000);

    fof_transport_state_note_tx(&state, false, 1001);
    fof_transport_state_note_rx(&state, false, 1002);
    fof_transport_state_note_heartbeat(&state);

    TEST_ASSERT_EQUAL_UINT32(1, state.tx_error_count);
    TEST_ASSERT_EQUAL_UINT32(1, state.rx_error_count);
    TEST_ASSERT_EQUAL_UINT32(1, state.heartbeat_count);
}
