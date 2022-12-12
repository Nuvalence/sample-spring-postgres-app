package io.nuvalence.sample.controller;

import io.nuvalence.sample.model.Customer;
import io.nuvalence.sample.repository.CustomerRepository;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

@RestController
@RequestMapping("/customer")
public class CustomerController {

    final CustomerRepository customerRepository;

    public CustomerController(CustomerRepository customerRepository) {
        this.customerRepository = customerRepository;
    }

    @PutMapping("")
    public Mono<Customer> registerCustomer(@RequestBody Customer customer) {
        return customerRepository.save(customer);
    }

    @DeleteMapping("/{customerId}")
    public Mono<Void> deleteCustomer(@PathVariable Long customerId) {
        return customerRepository.deleteById(customerId);
    }

    @GetMapping("/{customerId}")
    public Mono<Customer> fetchCustomer(@PathVariable Long customerId) {
        return customerRepository.findById(customerId);
    }
}
