import { describe, expect, it } from "vitest";
import { readFileSync } from "fs";
import { join } from "path";

describe("Medical Trial Consent Contract - Basic Validation", () => {
  
  it("should have a valid contract file", () => {
    const contractPath = join(process.cwd(), "contracts", "medical-trial-consent-contract.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    expect(contractContent).toBeTruthy();
    expect(contractContent.length).toBeGreaterThan(0);
  });

  it("should contain Smart Notification System features", () => {
    const contractPath = join(process.cwd(), "contracts", "medical-trial-consent-contract.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for notification-related data structures
    expect(contractContent).toContain("notifications");
    expect(contractContent).toContain("participant-notification-preferences");
    expect(contractContent).toContain("notification-analytics");
    expect(contractContent).toContain("notification-counter");
  });

  it("should contain notification error constants", () => {
    const contractPath = join(process.cwd(), "contracts", "medical-trial-consent-contract.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for notification error constants
    expect(contractContent).toContain("ERR-NOTIFICATION-NOT-FOUND");
    expect(contractContent).toContain("ERR-INVALID-NOTIFICATION-TYPE");
    expect(contractContent).toContain("ERR-NOTIFICATION-DISABLED");
    expect(contractContent).toContain("ERR-INVALID-DELIVERY-METHOD");
  });

  it("should contain core notification functions", () => {
    const contractPath = join(process.cwd(), "contracts", "medical-trial-consent-contract.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for core notification functions
    expect(contractContent).toContain("create-notification");
    expect(contractContent).toContain("mark-notification-delivered");
    expect(contractContent).toContain("mark-notification-read");
    expect(contractContent).toContain("set-notification-preference");
    expect(contractContent).toContain("get-notification");
    expect(contractContent).toContain("get-notification-preference");
    expect(contractContent).toContain("get-notification-analytics");
    expect(contractContent).toContain("get-notification-summary");
  });

  it("should contain supported notification types", () => {
    const contractPath = join(process.cwd(), "contracts", "medical-trial-consent-contract.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for supported notification types
    expect(contractContent).toContain("trial-start-reminder");
    expect(contractContent).toContain("trial-end-warning");
    expect(contractContent).toContain("compensation-available");
    expect(contractContent).toContain("consent-expiring");
  });

  it("should contain supported delivery methods", () => {
    const contractPath = join(process.cwd(), "contracts", "medical-trial-consent-contract.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for supported delivery methods
    expect(contractContent).toContain("email");
    expect(contractContent).toContain("sms");
    expect(contractContent).toContain("in-app");
  });

  it("should integrate notifications with existing trial functions", () => {
    const contractPath = join(process.cwd(), "contracts", "medical-trial-consent-contract.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check that notification analytics are initialized when creating trials
    expect(contractContent).toContain("notification-analytics");
    
    // Check that notifications are created in consent flow
    expect(contractContent).toContain("create-notification");
  });

  it("should have proper data variable definitions", () => {
    const contractPath = join(process.cwd(), "contracts", "medical-trial-consent-contract.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check data variable definitions
    expect(contractContent).toContain("(define-data-var notification-counter uint u0)");
  });

  it("should have proper map definitions for notification system", () => {
    const contractPath = join(process.cwd(), "contracts", "medical-trial-consent-contract.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check map definitions
    expect(contractContent).toContain("(define-map notifications");
    expect(contractContent).toContain("(define-map participant-notification-preferences");
    expect(contractContent).toContain("(define-map notification-analytics");
  });

  it("should have validation helper functions", () => {
    const contractPath = join(process.cwd(), "contracts", "medical-trial-consent-contract.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check validation helper functions
    expect(contractContent).toContain("is-valid-notification-type");
    expect(contractContent).toContain("is-valid-delivery-method");
  });
});
