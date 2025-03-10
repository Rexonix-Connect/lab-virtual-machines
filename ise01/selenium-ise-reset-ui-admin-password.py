#!/usr/bin/env python3

from selenium import webdriver
from selenium.common.exceptions import TimeoutException, NoSuchElementException
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
#
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions
from selenium.webdriver.support.wait import WebDriverWait
#
from datetime import datetime
#
import argparse
import os

def getDriver():
    chrome_options = Options()
    chrome_options.add_argument("--headless")                  # Run Chrome in headless mode (no visible UI)
    chrome_options.add_argument("--no-sandbox")                # Often needed in containerized/CI environments
    chrome_options.add_argument("--disable-dev-shm-usage")     # Bypass /dev/shm issue if it's limited
    chrome_options.add_argument("--disable-gpu")               # Potentially speeds up/avoids some issues on certain environments
    chrome_options.add_argument("--ignore-certificate-errors") # Tells Chrome not to reject self-signed certs
    chrome_options.add_argument("--allow-insecure-localhost")  # Allows navigation to pages on localhost with untrusted certs

    # Initialize the ChromeDriver using webdriver_manager
    driver = webdriver.Chrome(
        service=Service(ChromeDriverManager().install()),
        options=chrome_options
    )
    return driver

def iseLogin(driver, username=None, password=None, check_mode=False):
    try:
        loginPageReady = WebDriverWait(driver, 30).until(
            expected_conditions.all_of(
                expected_conditions.url_contains("login.jsp"),
                expected_conditions.presence_of_element_located((By.NAME, "username")),
                expected_conditions.element_to_be_clickable((By.NAME, "username")), 
                expected_conditions.presence_of_element_located((By.NAME, "password")),
                expected_conditions.element_to_be_clickable((By.NAME, "password")),
                expected_conditions.presence_of_element_located((By.ID, "loginPage_loginSubmit"))
            )
        )
    except TimeoutException:
        loginPageReady = False
    except NoSuchElementException:
        loginPageReady = False

    if check_mode:
        return loginPageReady

    if not loginPageReady:
        raise Exception(f"Failed to load ISE login page at {datetime.now()}")

    if not username or not password:
        raise Exception(f"Username and password are required to login to ISE at {datetime.now()}")

    username_field = driver.find_element(By.NAME, "username")
    username_field.click()
    username_field.send_keys(username)
    password_field = driver.find_element(By.NAME, "password")
    password_field.click()
    password_field.send_keys(password)
    submit_button = driver.find_element(By.ID, "loginPage_loginSubmit")
    submit_button.click()

def main():

    # process arguments, failover to environment variables
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", type=str, default=os.getenv("ISE_HOST", ""), help="Cisco ISE hostname or IP address (env ISE_HOST) (required)")
    parser.add_argument("--username", type=str, default=os.getenv("ISE_USERNAME", ""), help="Cisco ISE username (env ISE_USERNAME) (required)")
    parser.add_argument("--old-password", type=str, default=os.getenv("ISE_OLD_PASSWORD", ""), help="Cisco ISE initial admin password (env ISE_OLD_PASSWORD) (required)")
    parser.add_argument("--new-password", type=str, default=os.getenv("ISE_NEW_PASSWORD", ""), help="Cisco ISE final admin password (env ISE_NEW_PASSWORD) (required)")
    args = parser.parse_args()
    host = args.host
    username = args.username
    old_password = args.old_password
    new_password = args.new_password

    if not host or not username or not old_password or not new_password:
        parser.print_help()
        exit(1)
    
    baseUrl = f"https://{host}/admin/login.jsp"
    driver = getDriver()

    try:
        driver.get(baseUrl)
        driver.set_window_size(1920, 1040)
        # Login
        iseLogin(driver, username, old_password)
        # Initial enforced password change
        try:
            passwordResetURLCheck = WebDriverWait(driver, 30).until(
                expected_conditions.all_of(
                    expected_conditions.url_contains("resetPassword"),
                    expected_conditions.presence_of_element_located((By.ID, "PWD")),
                    expected_conditions.element_to_be_clickable((By.ID, "PWD")),
                    expected_conditions.presence_of_element_located((By.ID, "confirmPWD")),
                    expected_conditions.element_to_be_clickable((By.ID, "confirmPWD")),
                    expected_conditions.presence_of_element_located((By.ID, "rstBtn"))
                )
            )
        except TimeoutException:
            passwordResetURLCheck = False
        except NoSuchElementException:
            passwordResetURLCheck = False
        
        if not passwordResetURLCheck:
            raise Exception(f"Expected password reset redirect not found for {username} at {host} at {datetime.now()}")
        
        # enter and save new password
        newPasswordField = driver.find_element(By.ID, "PWD")
        newPasswordField.click()
        newPasswordField.send_keys(new_password)
        confirmPasswordField = driver.find_element(By.ID, "confirmPWD")
        confirmPasswordField.click()
        confirmPasswordField.send_keys(new_password)
        submitButton = driver.find_element(By.ID, "rstBtn")
        submitButton.click()
        
        # wait for login page to load
        if iseLogin(driver, check_mode=True):
            print(f"Successfully reset ISE admin password for {username} at {host} at {datetime.now()}")
        else:
            raise Exception(f"Failed to reset ISE admin password for {username} at {host} at {datetime.now()}")
    finally:
        driver.quit()

if __name__ == "__main__":
    main()
