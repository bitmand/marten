---
title: Cross-Site Request Forgery protection
description: Learn about Cross-Site Request Forgeries (CSRF) attacks and how to protect your application from them.
sidebar_label: CSRF protection
---

This document describes Marten's Cross-Site Request Forgery (CSRF) protection mechanism as well as the various tools that you can use in order to configure and make use of it.

## Overview

Cross-Site Request Forgery (CSRF) attacks generally involve a malicious website trying to perform actions on a web application on behalf of an already authenticated user. Marten provides a built-in mechanism in order to protect your applications from this kind of attack. This mechanism is useful for protecting endpoints that handle "unsafe" HTTP requests (ie. requests whose methods are not `GET`, `HEAD`, `OPTIONS`, or `TRACE`).

:::caution
The CSRF protection ignores safe HTTP requests. As such, you should ensure that those are side effect free.
:::

The CSRF protection provided by Marten is based on the verification of a token that must be provided for each unsafe HTTP request. This token is stored in the client: Marten sends a token cookie with every HTTP response when the token value is requested in handlers ([`#get_csrf_token`](pathname:///api/0.2/Marten/Handlers/RequestForgeryProtection.html#get_csrf_token-instance-method) method) or templates (eg. through the use of the [`csrf_token`](../templates/reference/tags#csrf_token) tag). It should be noted that the actual value of the token cookie changes every time an HTTP response is returned to the client: this is because the actual secret token is scrambled using a mask that changes for every request where the CSRF token is requested and used.

The token value must be specified when submitting unsafe HTTP requests: this can be done either in the data itself (by specifying a `csrftoken` input) or by using a specific header (X-CSRF-Token). When receiving this value, Marten compares it to the token cookie value: if the tokens are not valid, or if there is a mismatch, then this means that the request is malicious and that it must be rejected (which will result in a 403 error).

Finally, it should be noted that a few additional checks can be performed in addition to the token verification:

* in order to protect against cross-subdomain attacks, the HTTP request host will be verified in order to ensure that it is either part of the allowed hosts ([`allowed_hosts`](../development/reference/settings#allowed_hosts) setting) or that the value of the Origin header matches the configured trusted origins ([`csrf.trusted_origins`](../development/reference/settings#trusted_origins) setting)
* the Referer header will also be checked for HTTPS requests (if the Origin header is not set) in order to prevent subdomains to perform unsafe HTTP requests on the protected web applications (unless those subdomains are explicitly allowed as part of the [`csrf.trusted_origins`](../development/reference/settings#trusted_origins) setting)

The Cross-Site Request Forgery protection provided by Marten happens at the handler level automatically. This protection is implemented in the [`Marten::Handlers::RequestForgeryProtection`](pathname:///api/0.2/Marten/Handlers/RequestForgeryProtection.html) module.

## Basic usage

You should first ensure that the CSRF protection is enabled, which is the case by default when projects are generated through the use of the [`new`](../development/reference/management-commands#new) management command. That being said, if the CSRF protection is globally disabled (when the [`csrf.protection_enabled`](../development/reference/settings#protection_enabled) setting is set to `false`) you need to ensure that your handler enables it _locally_. For example:

```crystal
class MyHandler < Marten::Handler
  protect_from_forgery true

  # [...]
end
```

Then all you need to do is to ensure that you include the CSRF token when submitting unsafe HTTP requests to your web application. How to do that depends on _how_ you intend to submit these requests.

### Using CSRF protection with forms

If you need to embed the CSRF token into a form that is generated by a [template](../templates), then you can make use of the [`csrf_token`](../templates/reference/tags#csrf_token) template tag in order to define a hidden `csrftoken` input.

For example:

```html
<form method="post" action="" novalidate>
  <input type="hidden" name="csrftoken" value="{% csrf_token %}" />

  <!-- [...] -->

  <fieldset>
    <button>Submit</button>
  </fieldset>
</form>
```

:::caution
You should never define a hidden `csrftoken` input in a form that does not target your application directly. This is to prevent your CSRF token from being leaked.
:::

### Using the CSRF protection with AJAX

If you need to submit unsafe HTTP requests on the client side using AJAX, then you also need to ensure that the CSRF token is specified in the request. In this light, you can generate requests that include a X-CSRF-Token header with the token value. But you first need to retrieve the CSRF token. To get it you can either:

* retrieve the CSRF token from the cookies (which can be done only if the [`csrf.cookie_http_only`](../development/reference/settings#cookie_http_only) setting is set to `false`)
* or insert the CSRF token somewhere in your HTML markup (which is the way to go if the [`csrf.cookie_http_only`](../development/reference/settings#cookie_http_only) setting is set to `true`)

Retrieving the CSRF token from the cookies on the client side can be easily done by using a dedicated library such as the [JavaScript Cookie](https://www.npmjs.com/package/cookie) one:

```javascript
const csrfToken = Cookies.get("csrftoken");
```

If you can't leverage this technique because the [`csrf.cookie_http_only`](../development/reference/settings#cookie_http_only) setting is set to `true`, then you can also define the CSRF token as a JavaScript variable on the template side (by using the [`csrf_token`](../templates/reference/tags#csrf_token) template tag):

```html
<script>
const csrfToken = "{% csrf_token %}";
</script>
```

An alternative approach could also involve defining an invisible tag with a data attribute, and retrieving this value in order to define a JavaScript variable containing the token value:

```html
<div id="csrf_token" data-csrf-token="{% csrf_token %}"></div>
<script>
const csrfToken = document.getElementById("csrf_token").dataset.csrfToken;
</script>
```

Once you have the CSRF token value, all you need to do is to ensure that a X-CSRF-Token header is set with this value in all the unsafe HTTP requests you are issuing.

## Configuring the CSRF protection

The CSRF protection is enabled by default and can be configured through the use of a [dedicated set of settings](../development/reference/settings#csrf-settings). These settings can be used to enable or disable the protection globally, tweak some of the parameters of the CSRF token cookie, change the trusted origins, etc.

## Enabling or disabling the protection on a per-handler basis

Regardless of the value of the [`csrf.protection_enabled`](../development/reference/settings#protection_enabled) setting, it is possible to enable or disable the CSRF protection on a per-handler basis. This can be achieved through the use of the [`#protect_from_forgery`](pathname:///api/0.2/Marten/Handlers/RequestForgeryProtection/ClassMethods.html#protect_from_forgery(protect%3ABool)%3ANil-instance-method) class method, which takes a single boolean as arguments:

```crystal
class ProtectedHandler < Marten::Handler
  protect_from_forgery true

  # [...]
end

class UnprotectedHandler < Marten::Handler
  protect_from_forgery false

  # [...]
end
```