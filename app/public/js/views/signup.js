
$(document).ready(function(){
	
	var av = new AccountValidator();
	var sc = new SignupController();
	
	$('#account-form').ajaxForm({
		beforeSubmit : function(formData, jqForm, options){
			return av.validateForm();
		},
		success	: function(responseText, status, xhr, $form){
			if (status == 'success') $('.modal-alert').modal('show');
		},
		error : function(e){
			if (e.responseText == 'email-taken'){
			    av.showInvalidEmail();
			}	else if (e.responseText == 'username-taken'){
			    av.showInvalidUserName();
			}
		}
	});
	$('#name-tf').focus();
	
// customize the account signup form //
	
	$('#account-form h2').text('Registro');
	//$('#account-form #sub1').text('Please tell us a little about yourself');
	$('#account-form #sub2').text('Elige tu nombre de usuario y contraseña');
	$('#account-form-btn1').html('Cancelar');
	$('#account-form-btn2').html('Enviar');
	$('#account-form-btn2').addClass('btn-primary');
	
// setup the alert that displays when an account is successfully created //

	$('.modal-alert').modal({ show:false, keyboard : false, backdrop : 'static' });
	$('.modal-alert .modal-header h4').text('¡Cuenta creada!');
	$('.modal-alert .modal-body p').html('Tu cuenta ha sido creada.</br>Click en OK para volver al login.');

});