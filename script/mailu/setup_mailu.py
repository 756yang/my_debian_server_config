from selenium import webdriver
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.select import Select
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions

# Chrome浏览器是Selenium推荐使用的，windows上Selenium会自动下载测试版的Chrome
#1.创建Chrome浏览器对象，这会在电脑上在打开一个浏览器窗口
browser = webdriver.Chrome()

#2.通过浏览器向服务器发送URL请求
browser.get("https://setup.mailu.io/")

# 安装路径
input_box=browser.find_element("xpath",'//input[@name="root"]')
input_box.clear()
input_box.send_keys('/mailu')
# 主域名
input_box=browser.find_element("xpath",'//input[@name="domain"]')
input_box.clear()
input_box.send_keys('$server_domain')
# 主用户
input_box=browser.find_element("xpath",'//input[@name="postmaster"]')
input_box.clear()
input_box.send_keys('$username')
# 加密方式
select_box=browser.find_element("xpath",'//select[@name="tls_flavor"]')
Select(select_box).select_by_value('letsencrypt')
# 网站名称
input_box=browser.find_element("xpath",'//input[@name="site_name"]')
input_box.clear()
input_box.send_keys('$mail_site_name')
# 网站链接
input_box=browser.find_element("xpath",'//input[@name="website"]')
input_box.clear()
input_box.send_keys('https://mail.$server_domain')
# 开启管理UI
check_box=browser.find_element("xpath",'//input[@name="admin_enabled"]')
if not(check_box.is_selected()):
    check_box.click()
# 管理界面路径
#input_box=browser.find_element("xpath",'//input[@name="admin_path"]')
#input_box.clear()
#input_box.send_keys('/admin')
# 开启RESTful API
check_box=browser.find_element("xpath",'//input[@name="api_enabled"]')
if not(check_box.is_selected()):
    check_box.click()
# 网页邮件客户端
select_box=browser.find_element("xpath",'//select[@name="webmail_type"]')
Select(select_box).select_by_value('roundcube')
# 关闭反病毒ClamAV
check_box=browser.find_element("xpath",'//input[@name="antivirus_enabled"]')
if (check_box.is_selected()):
    check_box.click()
# 开启webdav存储联系人和日历信息
check_box=browser.find_element("xpath",'//input[@name="webdav_enabled"]')
if not(check_box.is_selected()):
    check_box.click()
# 开启fetchmail用以检索外部邮件
check_box=browser.find_element("xpath",'//input[@name="fetchmail_enabled"]')
if not(check_box.is_selected()):
    check_box.click()
# 开启oletools宏检测攻击行为
check_box=browser.find_element("xpath",'//input[@name="oletools_enabled"]')
if not(check_box.is_selected()):
    check_box.click()
# 公网IP地址
input_box=browser.find_element("xpath",'//input[@name="bind4"]')
input_box.clear()
input_box.send_keys('$mail_public_ip')
# 子网IP地址
input_box=browser.find_element("xpath",'//input[@name="subnet"]')
input_box.clear()
input_box.send_keys('192.168.203.0/24')
# 关闭IPv6
check_box=browser.find_element("xpath",'//input[@name="ipv6_enabled"]')
if (check_box.is_selected()):
    check_box.click()
# 开启内部DNS解析
check_box=browser.find_element("xpath",'//input[@name="resolver_enabled"]')
if not(check_box.is_selected()):
    check_box.click()
# 公共主机名
input_box=browser.find_element("xpath",'//input[@name="hostnames"]')
input_box.clear()
input_box.send_keys('mail.$server_domain')

# 获取下载docker配置文件的命令并打印
current_url=browser.current_url
WebDriverWait(browser,30).until(expected_conditions.url_changes(current_url))
if not(expected_conditions.url_changes(current_url)):
    input_box.send_keys(Keys.ENTER)
WebDriverWait(browser,30).until(expected_conditions.url_changes(current_url))
browser.get(browser.current_url)

code_items=browser.find_elements("xpath",'//code')
for code_item in code_items:
    code_text=code_item.text
    if ('wget ' in code_text):
        print(code_text)

browser.close()
