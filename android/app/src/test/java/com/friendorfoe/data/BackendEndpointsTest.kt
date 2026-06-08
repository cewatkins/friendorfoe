package com.friendorfoe.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BackendEndpointsTest {
    @Test
    fun candidates_include_both_wifi_addresses() {
        val urls = BackendEndpoints.candidates("http://192.168.1.218:8000/")

        assertTrue(urls.contains("http://192.168.1.208:8000/"))
        assertTrue(urls.contains("http://192.168.1.218:8000/"))
        assertEquals("http://192.168.1.218:8000/", urls.first())
    }
}