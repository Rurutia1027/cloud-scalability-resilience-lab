package com.tus.product;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;

import java.util.Map;

/**
 * Resolves the database password the way idm-service resolves {@code {VAULT:key}}:
 * the environment holds a secret id, and the process reads the current value at startup.
 * The password is not written to a Kubernetes Secret or to the process environment.
 */
public class SecretsManagerDbPasswordPostProcessor implements EnvironmentPostProcessor {

    static final String SECRET_ID = "DB_SECRET_ID";

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        String secretId = environment.getProperty(SECRET_ID);
        if (secretId == null || secretId.isBlank()) {
            return;
        }
        String region = environment.getProperty("AWS_REGION", "eu-west-1");
        environment.getPropertySources().addFirst(new MapPropertySource(
                "secrets-manager-db",
                Map.of("spring.datasource.password", readPassword(secretId, region))));
    }

    static String readPassword(String secretId, String region) {
        try (SecretsManagerClient client = SecretsManagerClient.builder()
                .region(Region.of(region))
                .httpClient(UrlConnectionHttpClient.create())
                .build()) {
            String secret = client.getSecretValue(GetSecretValueRequest.builder()
                    .secretId(secretId)
                    .build()).secretString();
            JsonNode password = new ObjectMapper().readTree(secret).get("password");
            if (password == null || password.asText().isBlank()) {
                throw new IllegalStateException("Secrets Manager secret has no password field: " + secretId);
            }
            return password.asText();
        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalStateException("Cannot read database password from Secrets Manager: " + secretId, e);
        }
    }
}
