﻿<%@ Page Title="" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="BookingCompletion.aspx.cs" Inherits="Website.BookingCompletion" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <div class="grid-container">
        <div>
            <p>Rum Nr.</p>
            <p>Tillægs ydelserne:</p>
            <p>Dobbeltseng</p>
        </div>
        <div>
            <p>Navn</p>
            <p>Adresse</p>
            <p>Post Nr.</p>
            <p>By</p>
            <p>Telefon Nr</p>
        </div>
        <div>
            <p>Pris per nat</p>
            <p>Fra Dato</p>
            <p>Til Dato</p>
            <p>Antal nætter</p>
            <h3>Pris i alt</h3>
            <input class="btnBooking" id="Button1" type="button" value="Book Nu" />
        </div>
    </div>
</asp:Content>
