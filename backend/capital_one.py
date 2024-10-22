from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
import logging
from concurrent.futures import ThreadPoolExecutor
import asyncio
import os
import time

logger = logging.getLogger(__name__)

async def login_navigate_and_download_capital_one(username: str, password: str) -> dict:
    def process():
        chrome_options = Options()
        download_dir = os.path.join(os.getcwd(), "downloads")
        os.makedirs(download_dir, exist_ok=True)
        chrome_options.add_experimental_option("prefs", {
            "download.default_directory": download_dir,
            "download.prompt_for_download": False,
            "download.directory_upgrade": True,
            "safebrowsing.enabled": True
        })

        service = Service(ChromeDriverManager().install())
        driver = webdriver.Chrome(service=service, options=chrome_options)

        try:
            driver.get("https://www.capitalone.com/")
            time.sleep(2)  # Wait for page to load

            # Login process
            username_input = WebDriverWait(driver, 10).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, 'input.login-username'))
            )
            username_input.click()
            time.sleep(0.5)
            username_input.send_keys(username)
            time.sleep(0.5)

            password_input = WebDriverWait(driver, 10).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, 'input.login-password'))
            )
            password_input.click()
            time.sleep(0.5)
            password_input.send_keys(password)
            time.sleep(0.5)

            submit_button = WebDriverWait(driver, 10).until(
                EC.element_to_be_clickable((By.CSS_SELECTOR, 'button.submit-btn'))
            )
            submit_button.click()
            time.sleep(30)  # Wait for login process

            logger.info("Login to Capital One successful")

            # Try to find and click on the "View More" button, but don't fail if it's not present
            try:
                view_more_button = WebDriverWait(driver, 10).until(
                    EC.element_to_be_clickable((By.XPATH,
                                                "//button[contains(@class, 'transaction-table_viewMore') or contains(text(), 'View More')]"))
                )
                view_more_button.click()
                time.sleep(1)
            except Exception as e:
                logger.warning(f"'View More' button not found or not clickable: {str(e)}")

            # Extract balance
            try:
                balance_dollars = driver.find_element(By.CSS_SELECTOR, 'div.primary-detail_balance__dollar').text
                balance_cents = driver.find_element(By.CSS_SELECTOR, 'div.primary-detail_balance__superscript').text
                balance = f"{balance_dollars}.{balance_cents}"
            except Exception as e:
                logger.warning(f"Unable to extract balance: {str(e)}")
                balance = "N/A"

            # Navigate directly to the Statements page
            statements_url = driver.current_url + "/Statements"
            driver.get(statements_url)
            time.sleep(5)  # Wait for statements page to load

            # Wait for the statements page to load completely
            WebDriverWait(driver, 20).until(
                lambda d: d.execute_script('return document.readyState') == 'complete'
            )
            time.sleep(2)  # Additional wait after page load

            # Click on the specific download button
            download_button_xpath = "//button[contains(@class, 'c1-ease-statement-viewer__menu-download') and .//span[text()='Download']]"
            download_button = WebDriverWait(driver, 10).until(
                EC.element_to_be_clickable((By.XPATH, download_button_xpath))
            )
            download_button.click()
            time.sleep(10)  # Wait for download to complete

            # Check if file was downloaded
            downloaded_files = os.listdir(download_dir)
            if downloaded_files:
                latest_file = max([os.path.join(download_dir, f) for f in downloaded_files], key=os.path.getctime)
                return {
                    "success": True,
                    "balance": balance,
                    "message": "Successfully downloaded statement",
                    "file_path": latest_file
                }
            else:
                return {
                    "success": False,
                    "balance": balance,
                    "message": "Statement download failed"
                }

        except Exception as e:
            logger.error(f"An error occurred during Capital One navigation: {str(e)}")
            return {"success": False, "message": str(e)}

        finally:
            driver.quit()

    # Run the Selenium process in a separate thread
    with ThreadPoolExecutor() as executor:
        return await asyncio.get_event_loop().run_in_executor(executor, process)