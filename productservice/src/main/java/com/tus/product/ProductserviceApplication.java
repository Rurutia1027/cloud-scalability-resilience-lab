package com.tus.product;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.web.client.RestTemplate;


@SpringBootApplication
public class ProductserviceApplication {

	@Bean
	public RestTemplate restTemplate(RestTemplateBuilder builder) {
		// The builder adds the OpenTelemetry client interceptor. new RestTemplate()
		// would call couponservice without a traceparent header, so the two
		// services would not share a trace.
		return builder.build();
	}

	public static void main(String[] args) {
		SpringApplication.run(ProductserviceApplication.class, args);
	}

}
