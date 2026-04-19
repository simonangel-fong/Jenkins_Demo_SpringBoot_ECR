package com.example.hello_world_api;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class HelloControllerTest {

    private final HelloController controller = new HelloController();

    @Test
    void helloReturnsMessage() {
        assertEquals("Hello, World!", controller.hello());
    }

    @Test
    void healthReturnsOk() {
        assertEquals("OK", controller.health());
    }
}
