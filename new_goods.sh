#!/bin/bash

# Параметры модуля
MODULE_NAME="new_products_page"
MODULE_VERSION="1.1"
AUTHOR="Your Name"
MODULE_DIR="new-products-page"

# Создаем структуру директорий
echo "Создаем структуру модуля..."
mkdir -p "${MODULE_DIR}/upload/admin/controller/extension/module"
mkdir -p "${MODULE_DIR}/upload/admin/language/en-gb/extension/module"
mkdir -p "${MODULE_DIR}/upload/admin/language/ru-ru/extension/module"
mkdir -p "${MODULE_DIR}/upload/admin/view/template/extension/module"
mkdir -p "${MODULE_DIR}/upload/catalog/controller/catalog"
mkdir -p "${MODULE_DIR}/upload/catalog/language/en-gb/catalog"
mkdir -p "${MODULE_DIR}/upload/catalog/language/ru-ru/catalog"
mkdir -p "${MODULE_DIR}/upload/catalog/view/theme/default/template/catalog"

# 1. Контроллер страницы новинок (с пагинацией и сортировкой)
cat > "${MODULE_DIR}/upload/catalog/controller/catalog/new_products.php" << 'EOL'
<?php
class ControllerCatalogNewProducts extends Controller {
    public function index() {
        $this->load->language('catalog/new_products');
        $this->document->setTitle($this->language->get('heading_title'));
        
        // Настройки пагинации
        $page = isset($this->request->get['page']) ? (int)$this->request->get['page'] : 1;
        $limit = $this->config->get('module_new_products_page_limit') ?: 20;
        
        $data['breadcrumbs'] = array(
            array(
                'text' => $this->language->get('text_home'),
                'href' => $this->url->link('common/home')
            ),
            array(
                'text' => $this->language->get('heading_title'),
                'href' => $this->url->link('catalog/new_products')
            )
        );

        $this->load->model('catalog/product');
        $this->load->model('tool/image');
        $this->load->model('catalog/category');

        $filter_data = array(
            'sort'  => 'p.date_added',
            'order' => 'DESC',
            'start' => ($page - 1) * $limit,
            'limit' => $limit
        );

        $product_total = $this->model_catalog_product->getTotalProducts($filter_data);
        $results = $this->model_catalog_product->getProducts($filter_data);
        
        $data['products'] = array();
        foreach ($results as $result) {
            if ($result['image']) {
                $image = $this->model_tool_image->resize($result['image'], 300, 300);
            } else {
                $image = $this->model_tool_image->resize('placeholder.png', 300, 300);
            }

            // Получаем категории товара
            $categories = $this->model_catalog_product->getCategories($result['product_id']);
            $category_names = array();
            foreach ($categories as $category) {
                $category_info = $this->model_catalog_category->getCategory($category['category_id']);
                if ($category_info) {
                    $category_names[] = $category_info['name'];
                }
            }

            $data['products'][] = array(
                'product_id'  => $result['product_id'],
                'thumb'       => $image,
                'name'        => $result['name'],
                'description' => utf8_substr(strip_tags(html_entity_decode($result['description'], ENT_QUOTES, 'UTF-8')), 0, 120) . '..',
                'price'       => $this->currency->format($this->tax->calculate($result['price'], $result['tax_class_id'], $this->config->get('config_tax')), $this->session->data['currency']),
                'categories'  => implode(', ', $category_names),
                'date_added'  => date($this->language->get('date_format_short'), strtotime($result['date_added'])),
                'href'        => $this->url->link('product/product', 'product_id=' . $result['product_id']),
                'add_to_cart' => $this->url->link('checkout/cart/add', 'product_id=' . $result['product_id'])
            );
        }

        // Пагинация
        $pagination = new Pagination();
        $pagination->total = $product_total;
        $pagination->page = $page;
        $pagination->limit = $limit;
        $pagination->url = $this->url->link('catalog/new_products', 'page={page}');
        $data['pagination'] = $pagination->render();

        $data['results'] = sprintf(
            $this->language->get('text_pagination'),
            ($product_total) ? (($page - 1) * $limit) + 1 : 0,
            ((($page - 1) * $limit) > ($product_total - $limit)) ? $product_total : ((($page - 1) * $limit) + $limit),
            $product_total,
            ceil($product_total / $limit)
        );

        $data['column_left'] = $this->load->controller('common/column_left');
        $data['column_right'] = $this->load->controller('common/column_right');
        $data['content_top'] = $this->load->controller('common/content_top');
        $data['content_bottom'] = $this->load->controller('common/content_bottom');
        $data['footer'] = $this->load->controller('common/footer');
        $data['header'] = $this->load->controller('common/header');
        
        $this->response->setOutput($this->load->view('catalog/new_products', $data));
    }
}
EOL

# 2. Шаблон страницы новинок (с улучшенным отображением)
cat > "${MODULE_DIR}/upload/catalog/view/theme/default/template/catalog/new_products.twig" << 'EOL'
{{ header }}
<div class="container">
  <ul class="breadcrumb">
    {% for breadcrumb in breadcrumbs %}
    <li><a href="{{ breadcrumb.href }}">{{ breadcrumb.text }}</a></li>
    {% endfor %}
  </ul>
  <div class="row">{{ column_left }}
    {% if column_left and column_right %}
    {% set class = 'col-sm-6' %}
    {% elseif column_left or column_right %}
    {% set class = 'col-sm-9' %}
    {% else %}
    {% set class = 'col-sm-12' %}
    {% endif %}
    <div id="content" class="{{ class }}">
      {{ content_top }}
      <h1>{{ heading_title }}</h1>
      
      {% if products %}
      <div class="row">
        <div class="col-md-3">
          <div class="btn-group hidden-xs">
            <button type="button" id="list-view" class="btn btn-default" data-toggle="tooltip" title="{{ button_list }}"><i class="fa fa-th-list"></i></button>
            <button type="button" id="grid-view" class="btn btn-default" data-toggle="tooltip" title="{{ button_grid }}"><i class="fa fa-th"></i></button>
          </div>
        </div>
        <div class="col-md-6 text-center">
          <div class="pagination-info">{{ results }}</div>
        </div>
      </div>
      <br>
      
      <div class="row product-layout-list">
        {% for product in products %}
        <div class="product-layout product-list col-xs-12">
          <div class="product-thumb">
            <div class="image"><a href="{{ product.href }}"><img src="{{ product.thumb }}" alt="{{ product.name }}" class="img-responsive" /></a></div>
            <div class="caption">
              <h4><a href="{{ product.href }}">{{ product.name }}</a></h4>
              <p><small>{{ text_category }}: {{ product.categories }}</small></p>
              <p><small>{{ text_date_added }}: {{ product.date_added }}</small></p>
              <p>{{ product.description }}</p>
              <p class="price">{{ product.price }}</p>
              <button type="button" onclick="cart.add('{{ product.product_id }}');" class="btn btn-primary">{{ button_cart }}</button>
            </div>
          </div>
        </div>
        {% endfor %}
      </div>
      
      <div class="row">
        <div class="col-sm-12 text-center">{{ pagination }}</div>
      </div>
      {% else %}
      <p>{{ text_empty }}</p>
      {% endif %}
      
      {{ content_bottom }}
    </div>
    {{ column_right }}
  </div>
</div>
{{ footer }}
EOL

# 3. Языковые файлы для каталога (английский)
cat > "${MODULE_DIR}/upload/catalog/language/en-gb/catalog/new_products.php" << 'EOL'
<?php
// Heading
$_['heading_title'] = 'New Products';

// Text
$_['text_home'] = 'Home';
$_['text_empty'] = 'There are no new products.';
$_['text_pagination'] = 'Showing %d to %d of %d (%d Pages)';
$_['text_category'] = 'Categories';
$_['text_date_added'] = 'Added on';
$_['button_cart'] = 'Add to Cart';
$_['button_list'] = 'List';
$_['button_grid'] = 'Grid';
$_['date_format_short'] = 'm/d/Y';
EOL

# 4. Языковые файлы для каталога (русский)
cat > "${MODULE_DIR}/upload/catalog/language/ru-ru/catalog/new_products.php" << 'EOL'
<?php
// Heading
$_['heading_title'] = 'Новинки';

// Text
$_['text_home'] = 'Главная';
$_['text_empty'] = 'Новых товаров нет.';
$_['text_pagination'] = 'Показано с %d по %d из %d (всего %d страниц)';
$_['text_category'] = 'Категории';
$_['text_date_added'] = 'Добавлено';
$_['button_cart'] = 'В корзину';
$_['button_list'] = 'Списком';
$_['button_grid'] = 'Сеткой';
$_['date_format_short'] = 'd.m.Y';
EOL

# 5. Контроллер модуля в админке (с настройками)
cat > "${MODULE_DIR}/upload/admin/controller/extension/module/${MODULE_NAME}.php" << 'EOL'
<?php
class ControllerExtensionModuleNewProductsPage extends Controller {
    private $error = array();

    public function index() {
        $this->load->language('extension/module/new_products_page');

        $this->document->setTitle($this->language->get('heading_title'));

        $this->load->model('setting/setting');

        if (($this->request->server['REQUEST_METHOD'] == 'POST') && $this->validate()) {
            $this->model_setting_setting->editSetting('module_new_products_page', $this->request->post);
            $this->session->data['success'] = $this->language->get('text_success');
            $this->response->redirect($this->url->link('marketplace/extension', 'user_token=' . $this->session->data['user_token'] . '&type=module', true));
        }

        $data['error_warning'] = isset($this->error['warning']) ? $this->error['warning'] : '';

        $data['breadcrumbs'] = array();
        $data['breadcrumbs'][] = array(
            'text' => $this->language->get('text_home'),
            'href' => $this->url->link('common/dashboard', 'user_token=' . $this->session->data['user_token'], true)
        );
        $data['breadcrumbs'][] = array(
            'text' => $this->language->get('text_extension'),
            'href' => $this->url->link('marketplace/extension', 'user_token=' . $this->session->data['user_token'] . '&type=module', true)
        );
        $data['breadcrumbs'][] = array(
            'text' => $this->language->get('heading_title'),
            'href' => $this->url->link('extension/module/new_products_page', 'user_token=' . $this->session->data['user_token'], true)
        );

        $data['action'] = $this->url->link('extension/module/new_products_page', 'user_token=' . $this->session->data['user_token'], true);
        $data['cancel'] = $this->url->link('marketplace/extension', 'user_token=' . $this->session->data['user_token'] . '&type=module', true);

        // Настройки по умолчанию
        $settings = array(
            'module_new_products_page_status' => 0,
            'module_new_products_page_limit' => 20,
            'module_new_products_page_image_width' => 300,
            'module_new_products_page_image_height' => 300
        );

        foreach ($settings as $key => $default) {
            if (isset($this->request->post[$key])) {
                $data[$key] = $this->request->post[$key];
            } elseif ($this->config->has($key)) {
                $data[$key] = $this->config->get($key);
            } else {
                $data[$key] = $default;
            }
        }

        $data['header'] = $this->load->controller('common/header');
        $data['column_left'] = $this->load->controller('common/column_left');
        $data['footer'] = $this->load->controller('common/footer');

        $this->response->setOutput($this->load->view('extension/module/new_products_page', $data));
    }

    protected function validate() {
        if (!$this->user->hasPermission('modify', 'extension/module/new_products_page')) {
            $this->error['warning'] = $this->language->get('error_permission');
        }

        if (!isset($this->request->post['module_new_products_page_limit']) || !is_numeric($this->request->post['module_new_products_page_limit'])) {
            $this->error['limit'] = $this->language->get('error_limit');
        }

        return !$this->error;
    }

    public function install() {
        $this->load->model('design/layout');
        $this->load->model('setting/setting');
        
        // Создаем макет
        $layout_data = array(
            'name' => 'New Products Page',
            'layout_route' => array(
                array(
                    'store_id' => 0,
                    'route' => 'catalog/new_products'
                )
            )
        );
        $this->model_design_layout->addLayout($layout_data);
        
        // Устанавливаем настройки по умолчанию
        $default_settings = array(
            'module_new_products_page_status' => 1,
            'module_new_products_page_limit' => 20,
            'module_new_products_page_image_width' => 300,
            'module_new_products_page_image_height' => 300
        );
        $this->model_setting_setting->editSetting('module_new_products_page', $default_settings);
    }

    public function uninstall() {
        $this->load->model('design/layout');
        $this->load->model('setting/setting');
        
        // Удаляем макет
        $layouts = $this->model_design_layout->getLayouts();
        foreach ($layouts as $layout) {
            if ($layout['name'] == 'New Products Page') {
                $this->model_design_layout->deleteLayout($layout['layout_id']);
                break;
            }
        }
        
        // Удаляем настройки
        $this->model_setting_setting->deleteSetting('module_new_products_page');
    }
}
EOL

# 6. Языковые файлы для админки (английский)
cat > "${MODULE_DIR}/upload/admin/language/en-gb/extension/module/${MODULE_NAME}.php" << 'EOL'
<?php
// Heading
$_['heading_title'] = 'New Products Page';

// Text
$_['text_extension'] = 'Extensions';
$_['text_success'] = 'Success: You have modified New Products Page module!';
$_['text_edit'] = 'Edit New Products Page Module';
$_['text_enabled'] = 'Enabled';
$_['text_disabled'] = 'Disabled';

// Entry
$_['entry_status'] = 'Status';
$_['entry_limit'] = 'Products Limit';
$_['entry_image_width'] = 'Image Width';
$_['entry_image_height'] = 'Image Height';

// Help
$_['help_limit'] = 'Number of products to display per page';
$_['help_image'] = 'Image dimensions for product thumbnails';

// Error
$_['error_permission'] = 'Warning: You do not have permission to modify New Products Page module!';
$_['error_limit'] = 'Limit must be a positive number!';
$_['error_image_width'] = 'Image width required!';
$_['error_image_height'] = 'Image height required!';
EOL

# 7. Языковые файлы для админки (русский)
cat > "${MODULE_DIR}/upload/admin/language/ru-ru/extension/module/${MODULE_NAME}.php" << 'EOL'
<?php
// Heading
$_['heading_title'] = 'Страница новинок';

// Text
$_['text_extension'] = 'Расширения';
$_['text_success'] = 'Успешно: Вы изменили модуль страницы новинок!';
$_['text_edit'] = 'Редактировать модуль страницы новинок';
$_['text_enabled'] = 'Включено';
$_['text_disabled'] = 'Отключено';

// Entry
$_['entry_status'] = 'Статус';
$_['entry_limit'] = 'Лимит товаров';
$_['entry_image_width'] = 'Ширина изображения';
$_['entry_image_height'] = 'Высота изображения';

// Help
$_['help_limit'] = 'Количество товаров на странице';
$_['help_image'] = 'Размеры изображений товаров';

// Error
$_['error_permission'] = 'Предупреждение: У вас нет прав на изменение модуля страницы новинок!';
$_['error_limit'] = 'Лимит должен быть положительным числом!';
$_['error_image_width'] = 'Требуется указать ширину изображения!';
$_['error_image_height'] = 'Требуется указать высоту изображения!';
EOL

# 8. Шаблон админки (с настройками)
cat > "${MODULE_DIR}/upload/admin/view/template/extension/module/${MODULE_NAME}.twig" << 'EOL'
{{ header }}{{ column_left }}
<div id="content">
  <div class="page-header">
    <div class="container-fluid">
      <div class="pull-right">
        <button type="submit" form="form-module" data-toggle="tooltip" title="{{ button_save }}" class="btn btn-primary"><i class="fa fa-save"></i></button>
        <a href="{{ cancel }}" data-toggle="tooltip" title="{{ button_cancel }}" class="btn btn-default"><i class="fa fa-reply"></i></a>
      </div>
      <h1>{{ heading_title }}</h1>
      <ul class="breadcrumb">
        {% for breadcrumb in breadcrumbs %}
        <li><a href="{{ breadcrumb.href }}">{{ breadcrumb.text }}</a></li>
        {% endfor %}
      </ul>
    </div>
  </div>
  <div class="container-fluid">
    {% if error_warning %}
    <div class="alert alert-danger alert-dismissible"><i class="fa fa-exclamation-circle"></i> {{ error_warning }}
      <button type="button" class="close" data-dismiss="alert">&times;</button>
    </div>
    {% endif %}
    <div class="panel panel-default">
      <div class="panel-heading">
        <h3 class="panel-title"><i class="fa fa-pencil"></i> {{ text_edit }}</h3>
      </div>
      <div class="panel-body">
        <form action="{{ action }}" method="post" enctype="multipart/form-data" id="form-module" class="form-horizontal">
          <div class="form-group">
            <label class="col-sm-2 control-label" for="input-status">{{ entry_status }}</label>
            <div class="col-sm-10">
              <select name="module_new_products_page_status" id="input-status" class="form-control">
                {% if module_new_products_page_status %}
                <option value="1" selected="selected">{{ text_enabled }}</option>
                <option value="0">{{ text_disabled }}</option>
                {% else %}
                <option value="1">{{ text_enabled }}</option>
                <option value="0" selected="selected">{{ text_disabled }}</option>
                {% endif %}
              </select>
            </div>
          </div>
          <div class="form-group">
            <label class="col-sm-2 control-label" for="input-limit">{{ entry_limit }}</label>
            <div class="col-sm-10">
              <input type="text" name="module_new_products_page_limit" value="{{ module_new_products_page_limit }}" placeholder="{{ entry_limit }}" id="input-limit" class="form-control" />
              {% if error_limit %}
              <div class="text-danger">{{ error_limit }}</div>
              {% endif %}
            </div>
          </div>
          <div class="form-group">
            <label class="col-sm-2 control-label" for="input-image-width">{{ entry_image_width }}</label>
            <div class="col-sm-10">
              <input type="text" name="module_new_products_page_image_width" value="{{ module_new_products_page_image_width }}" placeholder="{{ entry_image_width }}" id="input-image-width" class="form-control" />
              {% if error_image_width %}
              <div class="text-danger">{{ error_image_width }}</div>
              {% endif %}
            </div>
          </div>
          <div class="form-group">
            <label class="col-sm-2 control-label" for="input-image-height">{{ entry_image_height }}</label>
            <div class="col-sm-10">
              <input type="text" name="module_new_products_page_image_height" value="{{ module_new_products_page_image_height }}" placeholder="{{ entry_image_height }}" id="input-image-height" class="form-control" />
              {% if error_image_height %}
              <div class="text-danger">{{ error_image_height }}</div>
              {% endif %}
            </div>
          </div>
        </form>
        <div class="alert alert-info">
          <p>After enabling the module, a new page will be available at: <strong>{{ catalog_url }}index.php?route=catalog/new_products</strong></p>
          <p>You can add modules (like "Latest Products") to this page via the Layouts system.</p>
        </div>
      </div>
    </div>
  </div>
</div>
{{ footer }}
EOL

# 9. Файл install.xml
cat > "${MODULE_DIR}/install.xml" << 'EOL'
<?xml version="1.0" encoding="UTF-8"?>
<modification>
    <name>New Products Page</name>
    <version>${MODULE_VERSION}</version>
    <author>${AUTHOR}</author>
    <link>#</link>
    <code>${MODULE_NAME}</code>
    
    <file path="admin/controller/common/menu.php">
        <operation>
            <search><![CDATA[\$data['text_zone']]]></search>
            <add position="after"><![CDATA[\t\t\$data['text_new_products_page'] = \$this->language->get('text_new_products_page');]]></add>
        </operation>
    </file>
    
    <file path="admin/language/en-gb/common/menu.php">
        <operation>
            <search><![CDATA[\$_['text_zone']]]></search>
            <add position="after"><![CDATA[\$_['text_new_products_page'] = 'New Products';]]></add>
        </operation>
    </file>
    
    <file path="admin/language/ru-ru/common/menu.php">
        <operation>
            <search><![CDATA[\$_['text_zone']]]></search>
            <add position="after"><![CDATA[\$_['text_new_products_page'] = 'Новинки';]]></add>
        </operation>
    </file>
</modification>
EOL

# 10. README файл
cat > "${MODULE_DIR}/README.txt" << 'EOL'
New Products Page Module for OpenCart 3
======================================

Version: ${MODULE_VERSION}
Author: ${AUTHOR}

Description:
------------
This module creates a dedicated "New Products" page in your OpenCart store that displays all products sorted by date added (newest first). Key features:

- Customizable product limit per page
- Configurable product image dimensions
- Pagination support
- Multi-language support
- SEO-friendly URLs
- Responsive design

Installation:
-------------
1. Upload the contents of the "upload" folder to your OpenCart root directory
2. Go to Admin Panel -> Extensions -> Installer and upload the .ocmod.zip file
3. Go to Admin Panel -> Extensions -> Modules and find "New Products Page"
4. Click "Install" and then "Edit" to configure the module

Configuration:
--------------
After installation, you can configure:
- Module status (enable/disable)
- Number of products per page
- Product image dimensions
- Layout via OpenCart's Layout system

The page will be available at: yourstore.com/index.php?route=catalog/new_products

Uninstallation:
--------------
1. Go to Admin Panel -> Extensions -> Modules and find "New Products Page"
2. Click "Uninstall" to remove the module
3. The module will automatically remove all created layouts and settings

Support:
--------
For support questions, please contact the author.
EOL

# Архивируем модуль
echo "Создаем архив модуля..."
cd "${MODULE_DIR}"
zip -r "../${MODULE_DIR}_v${MODULE_VERSION}.ocmod.zip" upload/ install.xml README.txt
cd ..

# Удаляем временные файлы
rm -rf "${MODULE_DIR}"

echo "Готово! Модуль создан: ${MODULE_DIR}_v${MODULE_VERSION}.ocmod.zip"
echo "Инструкции по установке:"
echo "1. Перейдите в админ-панель OpenCart: Расширения -> Установщик расширений"
echo "2. Загрузите файл ${MODULE_DIR}_v${MODULE_VERSION}.ocmod.zip"
echo "3. Перейдите в Расширения -> Модули и найдите 'New Products Page'"
echo "4. Нажмите 'Установить', а затем 'Редактировать' для настройки параметров"
echo "5. Страница будет доступна по адресу: yourstore.com/index.php?route=catalog/new_products"